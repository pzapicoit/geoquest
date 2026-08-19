## Context

`CaminoScreen` (`app/lib/screens/camino_screen.dart`) ya carga
`CaminoJugador` (con `entradas` y `puntosTotales`) desde
`SupabaseCaminoGateway.fetchCamino()`. `puntosTotales` ya llega hasta
`_BarraSuperior` → `_PildoraPuntos`, pero no hasta `_ParadaTile`, que
solo recibe el objeto `ParadaCamino` de su propia fila y no tiene forma
de conocer el total del jugador.

El estado bloqueado (candado + escala de grises) ya está implementado
en `_ParadaTile` y funciona correctamente por revisión de código; el
único hueco es la ausencia de test, no de comportamiento.

## Goals / Non-Goals

**Goals:**
- Sustituir `'${parada.estrellasRequeridas} ★'` por los puntos totales
  del jugador, formateados con separador de miles, en el indicador
  izquierdo de cada parada.
- Añadir test de regresión para el candado y el filtro de escala de
  grises de una parada bloqueada.

**Non-Goals:**
- No cambia la mecánica de desbloqueo (sigue basada en estrellas
  acumuladas vs. `estrellas_requeridas`); `estrellasRequeridas` sigue
  existiendo en `ParadaCamino` y se sigue usando para calcular
  `bloqueado`/`_meta`, solo deja de imprimirse en ese indicador.
- No toca el orden de temáticas en el camino (dato de la tabla
  `camino`, gestionable desde Panel → Camino).
- No añade ningún campo nuevo a la vista `camino_jugador` ni al
  gateway: `puntosTotales` ya viaja en `CaminoJugador`.

## Decisions

- **Pasar `puntosTotales` como parámetro de `_ParadaTile`** (en vez de
  envolver `ParadaCamino` con el total, o convertir `_ParadaTile` en
  `StatefulWidget`/`InheritedWidget`): es un `StatelessWidget` que ya
  recibe todo por constructor; añadir un `required this.puntosTotales`
  es el cambio más pequeño y sigue el mismo patrón que
  `_BarraSuperior(camino: camino)`. Alternativa descartada: guardar
  `puntosTotales` en cada `ParadaCamino` al mapear la fila en
  `camino_gateway.dart` — se descarta porque duplicaría el mismo valor
  en todas las filas dentro del modelo de datos, mezclando un dato de
  "camino completo" dentro de un modelo por-parada.
- **Reutilizar `_formatMiles`** (ya usado por `_PildoraPuntos`) en vez
  de introducir un formateador nuevo, para mantener el mismo formato de
  miles en toda la pantalla.
- **Formalizar el candado como requisito de spec** en vez de dejarlo
  solo como detalle de implementación: la spec actual de
  `app-player-path-home` ya dice que la parada bloqueada se muestra
  "íntegramente en gris/atenuada" pero nunca menciona el candado como
  elemento propio — se añade el requisito para que el test de esta
  change tenga una base formal y las futuras regresiones del candado
  las detecte `openspec verify`, no solo la revisión manual.

## Risks / Trade-offs

- [Confundir "puntos totales" con "puntos de esa parada"] → el
  indicador es idéntico en las 13 filas (mismo número), lo cual podría
  parecer un bug a primera vista si no se conoce el contexto → mitigar
  con un test que compruebe explícitamente que el valor es igual en
  todas las paradas, y dejarlo documentado en el propio código
  (comentario junto al widget).
- [Tests existentes que aserten el texto "N ★" del indicador dejan de
  compilar/pasar] → localizar y actualizar esos casos en
  `camino_screen_test.dart` como parte de esta change, no dejarlos
  rotos.
