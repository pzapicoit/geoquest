## Why

Tras usar la Home del camino vertical (INT-90, pulida en INT-105), el
indicador de la columna izquierda de cada parada muestra las estrellas
requeridas ("3 ★"), pero debe mostrar los puntos totales que lleva el
jugador — dato que ya se calcula y se ve en la píldora de la cabecera,
pero no junto a cada parada. Además, el estado bloqueado (candado +
portada en gris) ya funciona mecánicamente, pero ni el candado como
elemento propio ni la escala de grises están cubiertos por ningún
requisito formal ni por ningún test — un cambio futuro en `_ParadaTile`
podría romperlos sin que ningún test lo detecte.

## What Changes

- El indicador de la columna izquierda de cada parada deja de mostrar
  `estrellas_requeridas` como "N ★" y pasa a mostrar los puntos totales
  acumulados del jugador (mismo valor en todas las filas, formateado con
  separador de miles). El desbloqueo de niveles sigue basándose en
  estrellas — no cambia ningún criterio de negocio, solo qué número se
  imprime en ese indicador.
- Se formaliza como requisito que toda parada bloqueada muestra un
  icono de candado sobre su tarjeta (ya implementado) y se añade
  cobertura de test para el candado y para el filtro de escala de
  grises de la portada bloqueada (hoy sin test).

No incluye ningún cambio de código para el orden de temáticas
(Monumentos/Banderas): ya se resuelve leyendo `camino_jugador` ordenada
ascendente por `orden` (`camino_gateway.dart`) y posicionando el `orden`
más bajo abajo del todo (`camino_screen.dart`) — si el orden visible no
coincide con el deseado, es un dato de la columna `orden` de la tabla
`camino`, editable desde Panel → Camino, fuera del alcance de este
change.

## Capabilities

### New Capabilities
(ninguna)

### Modified Capabilities
- `app-player-path-home`: el indicador junto a cada parada pasa de
  mostrar estrellas requeridas a mostrar los puntos totales del
  jugador; se formaliza el requisito de que toda parada bloqueada
  muestra un icono de candado sobre su tarjeta.

## Impact

- `app/lib/screens/camino_screen.dart`: `_ParadaTile` (columna
  izquierda del indicador) y el widget que la instancia dentro de
  `_buildParadaAnimada`/`build` de `_CaminoScreenState` (necesita pasar
  `puntosTotales` hasta `_ParadaTile`).
- `app/test/camino_screen_test.dart`: nuevos casos de test para el
  candado y el filtro de escala de grises de una parada bloqueada, y
  actualización de los tests existentes que hoy esperan "N ★" en el
  indicador izquierdo.
- Sin cambios de backend, de esquema ni del panel de administración.
