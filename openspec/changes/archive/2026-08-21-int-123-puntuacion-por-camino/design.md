## Context

La puntuación del jugador se calcula hoy en dos sitios con la misma fórmula equivocada:

- `clasificacion_global` (`20260819000000_clasificacion_ranking.sql:46`) hace
  `sum(rd.puntos)` sobre `respuestas_desafio` unido a `intentos_nivel`.
- `camino_gateway.dart:80` pide `from('respuestas_desafio').select('puntos')` **sin filtro ni
  agregación** y lo suma en cliente con `sumarPuntos`.

Ambas suman el histórico completo, así que repetir una parada acumula. `clasificacion_por_camino`
y `clasificacion_por_tematica` ya agregan `progreso_usuario_nivel.mejor_puntaje` — la fuente
correcta, monótona por el `greatest(...)` de `cerrar_intento_nivel`
(`20260819170000_umbrales_estrellas_derivados.sql:174`). El defecto es que dos de las cuatro
superficies se quedaron atrás, no que falte el dato.

Restricciones que condicionan el diseño:

- `camino_jugador` es `security_invoker = false` y su aislamiento por jugador **no** viene de la
  RLS de `progreso_usuario_nivel` sino del filtro explícito `pun.usuario_id = auth.uid()` en el
  left join (D1 de INT-96). Cualquier columna nueva que lea otra tabla con RLS por usuario
  necesita ese filtro a mano.
- Convención de la casa, documentada dos veces
  (`20260818122000` y `20260819182000:7-10`): las columnas nuevas de una vista van **al final**,
  porque `create or replace view` no admite reordenar ni renombrar las existentes.
- `camino.puntosTotales` se reparte desde la Home a **cuatro** pantallas (Home, Login, Ranking,
  Comodines). Ninguna lo recalcula: todas reciben el valor ya cargado.

## Goals / Non-Goals

**Goals:**

- Una sola definición de "puntuación del jugador": suma del mejor intento por parada.
- El indicador de cada parada del riel muestra el acumulado hasta ella, y el último coincide
  con la píldora de la cabecera **por construcción**, no por coincidencia.
- La Home deja de descargar `respuestas_desafio` entera.
- `clasificacion_global` alineada con las otras dos clasificaciones.

**Non-Goals:**

- No se toca el cálculo por desafío: `calcular_puntaje`, la curva exponencial, el bonus por
  rapidez y `respuestas_desafio.puntos` quedan igual. Cambia la agregación, no la puntuación.
- No se toca el desbloqueo ni los umbrales de estrellas, que ya iban por `mejores_estrellas`.
- No se migra ni se congela ningún dato histórico (ver Riesgos).
- No se añade el índice de `progreso_usuario_nivel (camino_id)` ni ninguna otra optimización de
  INT-127, salvo la que cae sola al quitar la consulta a `respuestas_desafio`.

## Decisions

### D1 — La puntuación por parada viaja en `camino_jugador`, no en una RPC nueva

La app ya lee `camino_jugador` para pintar la Home, y `mejor_puntaje` vive en la tabla que la
vista ya tiene en el left join. Añadir la columna cuesta una expresión;
una RPC aparte costaría un viaje de red más y otra superficie que mantener.

*Alternativa descartada:* una RPC `puntuacion_jugador()` que devuelva el total. Resuelve el
síntoma 1 pero no el 2 (el riel necesita el desglose por parada), así que haría falta igual la
columna.

### D2 — `mejor_puntaje` se añade al final, con `create or replace view`

`coalesce(pun.mejor_puntaje, 0) as mejor_puntaje` como **última** columna del `select`. Así
`create or replace view` sigue siendo válido y se conservan los privilegios y las dependencias
de la vista, sin `drop` + `create` + volver a conceder.

El `coalesce` es obligatorio y no cosmético: el join es un `left join`, y una parada nunca
jugada no tiene fila de progreso. Sin él la columna llegaría `null` y el acumulado del riel se
rompería en la primera parada sin jugar.

No hace falta filtro de `usuario_id` nuevo: la columna se lee del mismo alias `pun` que ya está
filtrado por `pun.usuario_id = auth.uid()` en el left join existente. Esto es exactamente el
caso que advertía D1 de INT-96, y se cumple por reutilizar el join, no por suerte.

*Alternativa descartada:* `drop view` + `create view`. Necesario solo si hubiera que reordenar
columnas, que no es el caso, y rompería la convención ya documentada dos veces en el repo.

### D3 — El acumulado por parada se calcula en el cliente, no con una window function

La vista expone `mejor_puntaje` por parada; el acumulado (`puntosAcumulados`) y el total
(`puntosTotales`) se derivan en Dart con una función pura sobre la lista ya ordenada por
`orden`.

El motivo es el criterio de aceptación: "el último punto del riel coincide con la píldora de la
cabecera". Si el total y el acumulado salen del mismo recorrido sobre la misma lista, coinciden
**por construcción** y no hay forma de que divergan. Si el acumulado viniera de una window
function y el total de otra suma, serían dos cálculos que hay que mantener de acuerdo.

Ventajas secundarias: la función es pura y se prueba sin red (el patrón que INT-90 ya estableció
con `sumarPuntos`), y la vista se queda con una columna nueva en vez de dos.

*Alternativa descartada:* `sum(coalesce(pun.mejor_puntaje,0)) over (order by c.orden)` en la
vista. Es una línea de SQL y la vista ya usa window functions (`min(...) over ()` para
`es_actual`), así que era viable. Se descarta por lo de arriba: mueve el total y el acumulado a
sitios distintos. Reconsiderar si algún día el camino se pagina — entonces el cliente dejaría de
tener la lista completa y el cálculo tendría que subir al servidor.

### D4 — `clasificacion_global` agrega `mejor_puntaje` con `join camino`, copiando el patrón de `clasificacion_por_tematica`

El CTE `base` pasa de `respuestas_desafio` + `intentos_nivel` a `progreso_usuario_nivel` +
`join camino`. El resto de la función (rank sobre todo el conjunto, top acotado a [1,100], fila
propia siempre presente, fila con 0 si no hay nada agregable) no se toca: los CTE `ranking`,
`top_n`, `resultado` y `final` siguen igual.

El `join camino` no es decorativo: excluye el progreso huérfano (`camino_id` nulo, historial de
paradas que ya no están en el camino) con el mismo criterio que ya aplica
`clasificacion_por_tematica`, y hace que la global y `camino_jugador` cuenten exactamente el
mismo conjunto de paradas. Sin él, el ranking podría mostrar a un jugador puntos que su propia
Home no le muestra.

`niveles_superados` se puede leer del mismo `progreso_usuario_nivel` que ya se está recorriendo,
lo que elimina el CTE `superados` y su left join.

*Alternativa descartada:* mantener `respuestas_desafio` como fuente y quedarse con el máximo por
`(usuario_id, camino_id)` vía `intentos_nivel`. Da el mismo número reconstruyéndolo desde las
respuestas crudas, cuando `mejor_puntaje` ya lo tiene precalculado y es la fuente que usan las
otras dos clasificaciones. Sería una tercera forma de calcular lo mismo.

### D5 — `sumarPuntos` se sustituye, no se deja muerta

Es una función pública con tests propios (`camino_gateway_test.dart`). Al desaparecer su única
llamada, se elimina junto a su grupo de tests y la sustituye la función pura de acumulación de
D3, con tests nuevos. Dejarla sin uso "por si acaso" solo deja código muerto que aparenta estar
cubierto.

### D6 — Los tests que afirman el comportamiento viejo se reescriben, no se borran

Dos tests de `camino_screen_test.dart` afirman hoy lo contrario de lo que pide la spec nueva:

- `'el indicador izquierdo de cada parada muestra los puntos totales del jugador…'` espera
  `'1 234'` en las tres paradas.
- `'el indicador izquierdo muestra 0 cuando el jugador no tiene puntos'` sigue siendo válido en
  su intención (jugador sin puntos → 0) pero su fixture cambia.

Se reescriben para cubrir los escenarios nuevos (cada parada su acumulado, no decrece, la última
coincide con la cabecera). Las keys `parada-puntos-<caminoId>` y `camino-puntos` se mantienen:
el resto de la suite las usa y no hay razón para moverlas.

Los fixtures `_monumentos` / `_monumentos2` / `_banderas` necesitan el campo nuevo. Son `const`,
así que añadir un campo requerido obliga a tocarlos — deliberado: es lo que garantiza que ningún
test se quede pasando por un default silencioso.

### D7 — El subtítulo "Global · acumulado histórico" se corrige en el mismo cambio

Es una cadena de copy, no lógica, pero afirma justo lo que este cambio deja de ser cierto.
Dejarla para después significa publicar una pantalla que le promete al jugador que repetir suma.
Pasa a "Global · mejor intento por nivel".

### D8 — Los tests SQL consultan a cada jugador suplantándolo, no desde uno solo

`clasificacion_global` devuelve el top N **más la fila de quien llama** (D4 de INT-109), y
`test_clasificacion.sql` corre contra el remoto compartido, con datos reales de partidas de
desarrollo. Un jugador fixture consultado desde otro solo aparece si entra en el top real; si no
entra, el `SELECT INTO` no encuentra fila, deja la variable en `NULL`, y una comparación
`if v_puntuacion <> 800` con `NULL` **no se cumple**: la aserción pasa sin comprobar nada.

Este cambio agrava el riesgo, porque baja las puntuaciones fixture de miles a cientos: bajo la
fórmula vieja B y C tenían 5000 puntos, con la nueva tienen 300. Así que cada jugador se
consulta suplantándolo (`set_config('request.jwt.claim.sub', ...)`), que es lo que garantiza que
su fila viaje. `posicion` es un `rank()` sobre el conjunto completo, así que el valor es absoluto
y se puede comparar entre llamadas distintas — por eso el empate de B y C se puede comprobar con
dos llamadas separadas.

Además, cada aserción exige `is not null` de forma explícita, aunque la suplantación ya lo
garantice: si algún día la regla de la fila propia se rompiera, estos tests deben fallar en vez
de volverse vacíos. Esto alcanza también a las aserciones de B, C y E que ya existían desde
INT-109, que tenían la misma fragilidad latente.

## Risks / Trade-offs

**[Los totales de los jugadores existentes bajan]** → Es el objetivo del cambio, no un efecto
colateral: los puntos de más eran el bug. No se migra ni se compensa nada. Merece una línea en
el changelog. La alternativa (congelar el histórico y aplicar la regla nueva solo a partir de
ahora) obligaría a mantener las dos fórmulas para siempre y perpetuaría la incoherencia entre
la global y las otras dos clasificaciones.

**[El ranking global se reordena al desplegar]** → Quien más había repetido baja más. Es
correcto y no hay forma de evitarlo si la regla cambia. Conviene desplegar la migración y la app
juntas: si la migración va sola, el ranking usa la regla nueva y la píldora de la Home la vieja,
y el jugador ve dos números distintos para lo mismo.

**[Un cliente antiguo contra la vista nueva]** → No rompe: la columna se añade al final y
postgrest devuelve JSON por nombre, así que un cliente que no la conoce la ignora. Ese cliente
seguiría mostrando el total viejo, que es exactamente el desfase del párrafo anterior.

**[`create or replace view` falla si algo depende de la vista]** → No aplica hoy: ningún objeto
de las migraciones depende de `camino_jugador` (`camino_panel` es una vista independiente). Y
añadir al final es precisamente la operación que `create or replace` sí admite. Aun así, si
falla, el mensaje de Postgres lo dirá al aplicar y toca `drop`+`create` con sus grants.

**[Perder el dato "cuántos puntos ha hecho en total en su vida"]** → `respuestas_desafio` sigue
intacta, con cada respuesta y sus puntos. El histórico no se borra: deja de ser lo que se le
muestra al jugador como su puntuación. Cualquier métrica del panel que lo quiera lo tiene.

## Migration Plan

1. Migración SQL única con las dos piezas (`camino_jugador` y `clasificacion_global`): forman una
   sola definición de puntuación y separarlas dejaría un estado intermedio incoherente.
2. Pasar el linter de Supabase **antes** de dar la migración por buena, para no encadenar una
   migración de corrección de lint como pasó en `20260820170100` y `20260820200100` (punto 7 de
   INT-127).
3. Actualizar `backend/supabase/tests/test_clasificacion.sql` con los escenarios nuevos
   (repetir no suma, mejorar sí sube por la diferencia, huérfano excluido).
4. App: gateway → pantalla → tests, en ese orden.
5. Desplegar migración y app juntas (ver Riesgos).

**Rollback:** revertir la migración es un `create or replace view` a la definición anterior más
la función anterior; ningún dato se ha destruido, así que no hay pérdida. La app anterior
funciona contra la vista nueva (columna al final, ignorada).

## Open Questions

Ninguna que bloquee la implementación. Dos decisiones tomadas por defecto que el usuario puede
revertir al revisar:

- **Delta por parada al abrirla** ("+1.240 sobre tu mejor marca"): sugerido en la issue como
  nota de producto, **no** incluido aquí. Es una pantalla distinta (`resumen_nivel`) y una
  conversación de producto aparte.
- **Nombre del requisito** "Indicador de puntos totales junto a cada parada": se conserva tal
  cual para que el delta `MODIFIED` empareje exactamente con la spec existente, aunque
  "totales" ya no describa bien su contenido. Renombrarlo es un `RENAMED` que conviene hacer
  suelto, no mezclado con un cambio de comportamiento.
