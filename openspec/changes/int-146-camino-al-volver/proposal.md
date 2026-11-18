## Why

Al volver de una partida («Volver al camino» en el resumen), la Home aparece
desplazada arriba del todo, en la última parada, que suele estar bloqueada, en
vez de en la parada que se acaba de jugar. El jugador tiene que bajar a buscar su
nivel cada vez que termina uno.

Además, el riel de la izquierda enseña el mismo acumulado («3 727») junto a cada
parada bloqueada. Lo especificó INT-123 a propósito («las paradas sin jugar
repiten el acumulado anterior»), pero jugando se lee como si esas paradas ya
tuvieran puntos: siete veces la misma cifra al lado de siete candados.

## What Changes

- Al volver de jugar, la Home **conserva el camino en pantalla** mientras
  recarga, sin spinner a pantalla completa, y **vuelve a centrar** el scroll en
  la parada actual con los datos nuevos. Si se acaba de desbloquear una parada,
  el centrado va a la nueva actual.
- El riel muestra el acumulado **solo junto a las paradas desbloqueadas**. Las
  bloqueadas conservan su marca atenuada, pero sin cifra.
  **Cambia lo especificado en INT-123** para las paradas bloqueadas: las
  desbloqueadas sin jugar siguen repitiendo el acumulado anterior.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

- `app-player-path-home`:
  - «Auto-centrado en la parada actual al cargar»: también al volver de jugar,
    no solo al montar la Home.
  - «El camino recarga su progreso al volver de jugar»: la recarga no sustituye
    el camino por un spinner.
  - «Indicador de puntos totales junto a cada parada»: sin cifra en las paradas
    bloqueadas; la coincidencia con la barra superior se exige cuando la última
    parada está desbloqueada.

## Impact

- `app/lib/screens/camino_screen.dart`: `didPopNext` (reactivar el
  auto-centrado), el `builder` del `FutureBuilder` (solo spinner sin datos
  previos) y la columna del riel (cifra solo si está desbloqueada).
- Tests: `test/camino_screen_test.dart`.
- No cambian el backend ni las dependencias.
