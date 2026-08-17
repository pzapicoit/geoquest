## Context

`calcular_puntaje` (migración `20260815161014_calcular_distancia_puntaje.sql`) es
lineal con corte duro a 0 en 2.000 km. `responder_desafio`, el trigger
`respuestas_desafio_antes_de_insertar` y la RPC de revelado (migración
`20260817150000_responder_desafio_revela_lugar.sql`, que expone `puntos_maximos =
calcular_puntaje(0)`) la llaman por nombre, no reimplementan la fórmula.

En el panel, `NivelRecorrido.tsx` edita `puntaje_minimo_superar`,
`umbral_estrella_1/2/3` y `preguntas_por_partida` como enteros absolutos
independientes, validados por `validarConfiguracionNivel` (orden ascendente) en
`nivelRecorrido.ts`. La tabla `niveles` exige por `CHECK`:
`puntaje_minimo_superar <= umbral_estrella_1 <= umbral_estrella_2 <= umbral_estrella_3`.
`cerrar_intento_nivel` (dos versiones: `20260815182216_superacion_nivel_estrellas.sql`
y la más reciente `20260817120000_camino_secuencia_propia.sql`) ya no lee
`umbral_estrella_1` — el `else 1` cubre ese caso, documentado en el propio SQL.

## Goals / Non-Goals

**Goals:**
- Sustituir la curva de puntaje por la exponencial con suelo definida en la
  propuesta, sin cambiar la firma ni los llamadores de `calcular_puntaje`.
- Que el panel exprese los umbrales de 2 y 3 estrellas como porcentaje del máximo
  del nivel, mostrando el absoluto guardado y la distancia media que implica.
- Retirar `umbral_estrella_1` del formulario sin migrar/borrar la columna.

**Non-Goals:**
- No se toca `cerrar_intento_nivel` ni ninguna lógica de `level-progression`: sigue
  leyendo los mismos absolutos `umbral_estrella_2/3`, calculados como siempre.
- No se muestra al jugador el progreso hacia la siguiente estrella durante la
  partida (fuera de alcance, va en INT-94).
- No hay backfill de `respuestas_desafio` ya guardadas.
- No se elimina la columna `umbral_estrella_1` de `niveles`.

## Decisions

**Constantes con nombre en PL/pgSQL, no SQL puro con literales.**
La función actual es `language sql`. Para que `MAX`/`PISO`/`k` sean un dial de
ajuste real (pedido explícitamente en la propuesta), `calcular_puntaje` pasa a
`language plpgsql` con constantes locales nombradas. Alternativa descartada:
mantener `language sql` con los literales comentados inline — funciona pero no
dan un punto único evidente para tocar en un playtesting futuro.

**Nueva migración `create or replace`, no editar la original.**
Sigue el patrón ya usado en `20260817150000_responder_desafio_revela_lugar.sql`
(que también hace `create or replace` sobre funciones de la migración de INT-78).
Se añade una migración nueva con timestamp posterior al último existente.

**`N` efectivo se calcula en el panel, sin RPC nueva.**
El máximo del nivel es `N × 5000`, con `N = preguntas_por_partida` si está
definido o el tamaño del pool del recorrido (`preguntas.length`) si es `NULL` —
mismo criterio que ya usa `challenge-play` para decidir cuántas preguntas se
juegan. La pantalla de detalle del nivel ya carga ambos valores, así que el
cálculo es puramente local en `nivelRecorrido.ts`.

**Solo umbral 2 y 3 pasan a porcentaje; `puntaje_minimo_superar` se mantiene como
input absoluto.** La propuesta usa el 40% como valor de referencia para
"Superar/⭐", no como requisito de cambiar ese campo. Cambiarlo también a
porcentaje ampliaría el diff sin necesidad — se mantiene el campo actual y se le
añade, igual que a los otros, la distancia media derivada en modo lectura.
Alternativa descartada: convertir los tres a porcentaje (más consistente
visualmente, pero fuera del pedido concreto de la propuesta y con más superficie
de validación que tocar sin necesidad).

**`umbral_estrella_1`: se retira del formulario, la columna se fija = `puntaje_minimo_superar` al guardar, no se borra.**
Ya es una columna muerta (no leída por `cerrar_intento_nivel`). Borrarla exige una
migración sobre una columna `NOT NULL` con `CHECK` encadenado y activa en datos ya
sembrados — riesgo desproporcionado para una simplificación puramente cosmética
del formulario. Fijarla igual a `puntaje_minimo_superar` en cada guardado satisface
trivialmente `CHECK (puntaje_minimo_superar <= umbral_estrella_1)` sin tocar el
esquema.

**La distancia media inversa se calcula en el panel (TypeScript), no en el backend.**
Es puramente presentacional (`d = -k · ln((puntos - PISO) / (MAX - PISO))`), así que
no justifica una RPC. Duplica `MAX`/`PISO`/`k` como constante documentada en el
panel, con comentario cruzado a la migración SQL como fuente de verdad.

## Risks / Trade-offs

- **[Riesgo]** `MAX`/`PISO`/`k` duplicados entre SQL y panel pueden desincronizarse
  si se ajustan en un lado y no en el otro → **Mitigación**: comentario cruzado en
  ambos sitios señalando al otro, y los mismos pares (distancia, puntos) de la
  tabla de la propuesta se verifican tanto en los tests SQL como en los del panel.
- **[Riesgo]** `k=1500` no está validado con playtesting; una vez re-expresados los
  umbrales en porcentaje, un valor de `k` desajustado puede volver los niveles
  demasiado fáciles o difíciles → **Mitigación**: ya es el objetivo declarado que
  sea un único dial fácil de mover; no bloquea este cambio.
- **[Riesgo]** Niveles ya configurados con `umbral_estrella_2/3` absolutos de la
  curva vieja no se re-expresan automáticamente en porcentaje de la curva nueva →
  **Mitigación**: aceptable, coherente con "sin backfill" de la propuesta; los
  valores siguen siendo válidos para el `CHECK` y para `cerrar_intento_nivel`
  hasta que un admin re-guarde esa configuración.

## Migration Plan

1. Migración SQL (`create or replace calcular_puntaje`) — sin migración de datos,
   aplica de inmediato a la siguiente llamada de `responder_desafio` o insert en
   `respuestas_desafio`.
2. Cambio de panel (UI + `nivelRecorrido.ts`) — independiente en el tiempo, no
   cambia la forma de las columnas de `niveles`.
3. Rollback: revertir el `create or replace` a la fórmula lineal (otra migración,
   sin migración de datos); revertir el commit del panel por separado si hace
   falta.

## Open Questions

Ninguna pendiente — `MAX`/`PISO`/`k` se cierran con los valores de la propuesta,
marcados explícitamente como ajustables por playtesting posterior, sin bloquear
este cambio.
