## Why

Hoy la puntuación de un jugador es la **suma histórica de todas sus respuestas**, así que
repetir una parada acumula puntos en vez de quedarse con su mejor intento: jugar tres veces
el Nivel 1 suma los tres. Eso rompe el sentido del reintento (premia insistir, no mejorar) y
deja la puntuación midiendo algo distinto que las estrellas, que sí guardan el mejor resultado.

El mismo defecto tiene un segundo síntoma visible: el indicador de puntos del riel de la Home
repite el total en las tres paradas, porque no existe ningún dato de puntuación por parada que
pudiera mostrar.

La fuente correcta ya existe y ya es monótona: `progreso_usuario_nivel.mejor_puntaje`, que
`cerrar_intento_nivel` actualiza con `greatest(...)` en cada cierre.
`clasificacion_por_camino` y `clasificacion_por_tematica` ya la usan — solo
`clasificacion_global` y la app se quedaron con la suma histórica.

## What Changes

- **BREAKING (dato visible al jugador)**: la puntuación total pasa a ser
  `sum(mejor_puntaje)` sobre las paradas del camino en vez de `sum(puntos)` sobre
  `respuestas_desafio`. Repetir una parada solo puede subir su mejor marca, nunca acumular.
  Los totales existentes **bajan** para quien haya repetido paradas.
- La vista `camino_jugador` expone la puntuación por parada (`mejor_puntaje`), que hoy no
  viaja a la app en absoluto.
- El indicador de cada parada del riel pasa a mostrar el **acumulado hasta esa parada**
  (suma del mejor intento de las paradas de `orden` menor o igual), de forma que el último
  punto del riel coincide por construcción con la píldora de la cabecera.
- `clasificacion_global` agrega `progreso_usuario_nivel.mejor_puntaje` unido a `camino`, en
  vez de `respuestas_desafio.puntos` unido a `intentos_nivel`. Alinea la global con las otras
  dos clasificaciones, que ya lo hacían, y descarta el progreso huérfano
  (`camino_id IS NULL`) con el mismo criterio que `clasificacion_por_tematica`.
- La app deja de descargarse **todas** las filas de `respuestas_desafio` en cada carga de la
  Home para sumarlas en cliente. El total sale del mismo `camino_jugador` que ya se pide.
- El subtítulo "Global · acumulado histórico" de la pestaña Global del ranking deja de ser
  cierto y se reescribe.

`respuestas_desafio.puntos` **no cambia**: se sigue calculando y persistiendo igual por
desafío (`challenge-scoring` intacto). Lo que cambia es cómo se agrega para el jugador.

## Capabilities

### New Capabilities

Ninguna. El cambio corrige y reencaja comportamiento ya especificado.

### Modified Capabilities

- `player-path`: `camino_jugador` gana la puntuación del mejor intento por parada
  (`mejor_puntaje`), hoy ausente de la vista.
- `player-ranking`: `clasificacion_global` cambia su agregación de `respuestas_desafio.puntos`
  a `progreso_usuario_nivel.mejor_puntaje`, y excluye el progreso sin `camino_id`.
- `app-player-path-home`: cambian dos requisitos. "Barra superior con identidad, progreso y
  puntos totales" deja de definir el total como la suma de `puntos` de todas las filas de
  `respuestas_desafio`; e "Indicador de puntos totales junto a cada parada" pasa de repetir el
  total en todas las paradas a mostrar el acumulado hasta cada una — incluido su escenario
  actual "sin variar de una parada a otra", que se invierte.
- `app-ranking`: el subtítulo de la pestaña Global ya no describe un acumulado histórico.

`app-login` no cambia a nivel de spec: ya define sus datos como "lo que expone
`CaminoGateway` (vista `camino_jugador`)", y eso sigue siendo cierto.

## Impact

**Backend**
- `camino_jugador` (vista) — nueva columna; el orden de columnas cambia, así que
  `create or replace view` no basta.
- `clasificacion_global` (función) — se reescribe su CTE base.
- `backend/supabase/tests/test_clasificacion.sql` — sus asertos sobre la global cambian.

**App**
- `app/lib/services/camino_gateway.dart` — `ParadaCamino` gana campos, `fetchCamino()` pierde
  la consulta a `respuestas_desafio`, y `sumarPuntos` (función pública, hoy probada) queda sin
  uso y se sustituye.
- `app/lib/screens/camino_screen.dart` — `_ParadaTile` pinta el acumulado de su parada.
- Cuatro pantallas consumen `camino.puntosTotales` sin cambios propios (Home, Login, Ranking,
  Comodines): les llega el valor corregido por la misma vía.
- `app/lib/screens/ranking_screen.dart` — copy del subtítulo de la pestaña Global.

**Tests que afirman el comportamiento actual y deben reescribirse**
- `app/test/camino_screen_test.dart`: "el indicador izquierdo de cada parada muestra los
  puntos totales del jugador…" (espera `'1 234'` en las tres paradas) y "el indicador
  izquierdo muestra 0 cuando el jugador no tiene puntos".
- `app/test/camino_gateway_test.dart`: el grupo `sumarPuntos`.

**Sin impacto**
- El cálculo por desafío (`calcular_puntaje`, bonus por rapidez, curva exponencial).
- Los umbrales de estrellas y el desbloqueo, que ya iban por `mejores_estrellas`.
- `clasificacion_por_camino` y `clasificacion_por_tematica`, ya correctas.
