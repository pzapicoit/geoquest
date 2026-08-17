## Why

En el iPhone real el mapa se ve cortado y mal renderizado. Con INT-102 dentro
ya no hay franjas de fondo, así que lo que queda es del dibujo del mundo. Dos
defectos, los dos localizados en el dato y los dos verificados sobre
`app/assets/world/world_50m.bin` (241 países, 1629 anillos, 99 539 puntos) y
sobre el TopoJSON del que sale.

**1. La Antártida no llega al borde de la proyección.** En world-atlas el
continente viene como un polígono cuyo **anillo exterior es la arista del polo
—257 puntos, todos a -89,999°, área cero— y cuyo supuesto agujero es la costa**
(2539 puntos, área -3938). Son los dos arcos de un mismo anillo, y el
generador los trata como anillos sueltos. Resultado: la costa se cierra sobre
sí misma a ≈ -84,3°, el relleno se corta en seco a un 2 % del borde inferior,
y la arista del polo —que no rellena nada porque encierra área cero— sí se
traza en la pasada de contorno y pinta una raya a todo lo ancho pegada al
canto. Rasterizado:

```
y=0,960  lat -83,65  ####################################################
y=0,969  lat -83,99  ####################################################
y=0,978  lat -84,32  ##########################..........................
y=0,987  lat -84,62  ###.................................................
y=0,996  lat -84,91  .##.................................................
y=1,000  lat -85,05  ───────── raya de contorno a todo lo ancho ──────────
```

**2. Los cruces del antimeridiano se dibujan como rayas de borde a borde.**
Un anillo que pasa de 179,9° a -180° salta en la proyección de `x = 0,9996` a
`x = 0`, y ese salto se traza. Hay ocho segmentos así en el dataset —dos de
ellos son el caso de la Antártida—; los otros seis cruzan el mapa entero:

| Anillo | Latitud | Efecto |
|---|---|---|
| Rusia continental (4894 pts) | 69,0° y 65,0° | dos rayas de borde a borde por el Ártico y el Pacífico |
| Rusia, isla de Wrangel (43 pts) | 71,0° y 71,5° | dos rayas más, casi solapadas |
| Fiyi (10 pts) | -16,5° (×2) | raya por el Atlántico Sur, África, el Índico y Australia |

Las otras dos causas que apunta el issue —el coste de repintar el mundo cada
fotograma y la resolución del asset— **no se deciden aquí**: el propio issue
pide medir en dispositivo antes de tocar nada, y esa medida no se puede tomar
desde el repositorio. Este cambio cierra lo que sí está verificado y deja el
perfilado como tarea con un procedimiento concreto; lo que salga de él se
decide con el dato delante, en un delta si cambia la spec.

## What Changes

En `app/tool/build_world_asset.dart`, dos reglas sobre la geometría al
decodificar la topología:

- **Fusionar el polígono de cierre polar.** Cuando el anillo exterior de un
  polígono encierra área cero, sus anillos son los arcos de un mismo contorno:
  se concatenan en uno solo. El lado del ±180 de cada extremo lo decide el
  signo de su vértice vecino. La costa se acota además a -85,05°, un pelo
  dentro de la banda representable, para que no toque la arista del polo y no
  se cancele consigo misma en el relleno par-impar.
- **Partir los anillos que cruzan el antimeridiano.** Un vértice a |lng| = 180
  con vecinos en hemisferios opuestos es un cruce: el anillo se corta ahí y
  cada trozo se cierra por su lado del antimeridiano.

Medido aplicando las dos reglas al dataset: 1 polígono fusionado, 3 anillos
partidos, **241 países intactos**, 1629 → 1631 anillos, 99 539 → 99 541
puntos, **cero anillos de área cero** y **cero segmentos con salto de más de
180°**. El mundo pasa a rellenar hasta el canto inferior.

Además:

- Se **regenera y recommitea** `app/assets/world/world_50m.bin` (+24 bytes).
- Tests sobre el asset que fijan las invariantes, para que una regeneración
  futura no reintroduzca ninguno de los dos defectos.
- Se **perfila en dispositivo** el coste de pintado por fotograma (gesto de
  zoom y animación del revelado) y se deja el resultado anotado. **No se
  optimiza nada en este cambio**: si la medida confirma el coste, la caché o
  el recorte del dibujo entran como delta.
- Se **anota el límite real de la resolución 50m** a la vista del zoom máximo
  de 40× que dejó INT-102. La decisión de pasar a 10m, si procede, sale del
  mismo delta.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

- `app-world-map`: el mundo dibujado SHALL cubrir el cuadrado de la proyección
  hasta sus bordes y SHALL no trazar ningún segmento que no sea perímetro de
  tierra. Hoy la spec exige que no se vea fondo por ningún borde (INT-102),
  pero no dice nada de que el propio dibujo del mundo esté completo ni de que
  el contorno solo dibuje costas, y por ahí se cuelan los dos defectos.

## Impact

- `app/tool/build_world_asset.dart` — fusión del polígono polar y partido en
  el antimeridiano.
- `app/assets/world/world_50m.bin` — asset regenerado, +24 bytes.
- `app/test/mundo_geometria_test.dart` — invariantes nuevas sobre el asset
  commiteado.
- `.devplugin/architecture.md` — nota del perfilado en dispositivo y del
  límite encontrado en la resolución 50m.
- Sin cambios en `mercator.dart`, `mapa_mundi.dart` ni
  `mapa_mundi_controller.dart`: el arreglo es del dato, no del dibujo ni de la
  cámara.
- Fuera de alcance, a la espera de la medida en dispositivo: cachear o
  recortar el dibujo del mundo, y cambiar la resolución del asset.
