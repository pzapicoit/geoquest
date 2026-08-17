## Context

INT-92 empaquetó la geometría del mundo en un binario propio
(`app/assets/world/world_50m.bin`, 803 KB) generado por
`app/tool/build_world_asset.dart` a partir del TopoJSON de `world-atlas` 2.0.2
(Natural Earth 1:50m). El lector (`mundo_geometria.dart`) proyecta esos
anillos a un cuadrado `[0,1] × [0,1]` con Mercator y los mete todos en un
único `Path` con `PathFillType.evenOdd`. El pintor lo dibuja en dos pasadas:
relleno y contorno.

INT-102 ya cerró la parte de cámara del "se ve cortado" —las franjas de fondo
al alejar por debajo de la altura de pantalla— fijando `escalaMinima` a
`max(ancho, alto)` y el zoom máximo a 40×. Lo que queda es del dibujo del
mundo, y todo el análisis de este cambio se ha hecho **sobre el dato**,
decodificando el `.bin` y el TopoJSON de origen y rasterizando el relleno
par-impar fuera de Flutter. Los dos defectos son reproducibles sin dispositivo
y sin levantar un widget.

Lo que **no** se puede analizar desde el repositorio es el coste de pintado en
un iPhone con Impeller. El issue lo pide explícitamente antes de optimizar, y
por eso el perfilado entra como tarea de medida, no como cambio de código.

## Goals / Non-Goals

**Goals:**

- Que el relleno del mundo llegue al canto inferior de la proyección.
- Que la pasada de contorno no dibuje ningún trazo que no sea costa o
  frontera.
- Que las dos cosas queden fijadas por tests sobre el asset commiteado, no por
  inspección visual.
- Dejar medido, con números, el coste de pintado por fotograma en dispositivo
  y el zoom al que el asset 50m empieza a verse poligonal.

**Non-Goals:**

- Cachear, recortar o de cualquier forma cambiar **cómo** se pinta el mundo.
  Se decide con el perfilado delante, en un delta.
- Cambiar la resolución del asset a 10m. Misma razón.
- Tocar `Mercator`, `MapaMundiController` o `MapaMundi`. El arreglo es del
  dato; el código de dibujo y de cámara se queda como está.
- Reescribir el formato del binario. Sigue siendo `GQW1` con la misma
  cabecera, así que el lector no cambia.

## Decisions

**D1 — El arreglo va en el generador, no en el pintor.** Las dos alternativas
eran parchear el dibujo (pintar una franja de hielo tapando el corte, filtrar
anillos al construir el `Path`) o arreglar la geometría al generarla. Se elige
el generador porque el defecto **es** del dato: la Antártida de world-atlas
está mal repartida en anillos y los cruces del antimeridiano vienen sin
partir. Parchear el pintor obligaría a meter números mágicos de latitud en
código de dibujo y a pagar el filtrado en cada carga; arreglarlo en el
generador lo paga una vez, deja el `.bin` correcto por construcción y permite
comprobarlo con un test sobre bytes en vez de sobre píxeles.

**D2 — Un polígono cuyo anillo exterior encierra área cero es un cierre polar,
y sus anillos se fusionan en uno.** Así viene la Antártida en world-atlas:
`poligono#2 = [arco 1851 (257 pts a -89,999°, área 7,7e-12), arco 1852 (2539
pts de costa, área -3938)]`. No es un exterior con un agujero —un agujero no
puede ser mayor que su exterior—: son los dos arcos del mismo contorno, la
arista del polo y la costa, que el formato dejó separados. Concatenarlos
reconstruye el anillo que world-atlas quería describir.

La regla se ha barrido contra los 241 países del dataset y **encaja
exactamente una vez**. No es una regla escrita para la Antártida: es la
condición que hace degenerado a un polígono, y da la casualidad de que solo la
cumple la Antártida. Un dataset futuro con otro cierre polar entraría por el
mismo sitio.

Alternativas descartadas: reconocer la Antártida por su nombre o su índice
(frágil, se rompe al cambiar de dataset); recortarla del asset (el juego
consiste en reconocer costas, un continente menos es un desafío sin
respuesta); pintar una franja de hielo (número mágico en el pintor, y no quita
la raya del contorno).

**D3 — El lado del ±180 de un extremo lo decide el signo de su vecino.** Al
fusionar, los extremos de los dos arcos están guardados los cuatro como -180,
aunque geográficamente dos de ellos son +180. Si se dejan como vienen, los dos
conectores del anillo caen en `x = 0`, se superponen y **se cancelan en
par-impar**: el relleno no cambia nada. Comprobado: fusionar sin desambiguar
deja el corte exactamente igual que estaba.

Mirando el vecino, el arco del polo va de `x = 1` a `x = 0` y el de la costa
de `x = 0` a `x = 1`; los conectores quedan uno en cada borde y el anillo
cierra la banda entera. La regla se aplica **solo dentro del polígono que se
está fusionando**, nunca de forma global: Rusia y Fiyi también tienen vértices
a |lng| = 180 y ahí significan otra cosa (ver D5).

**D4 — La costa se acota a -85,05°, no al límite de Mercator.** Cuatro
vértices del anillo de la costa bajan a -85,19°, por debajo del límite
representable. Si se acotan al propio límite (-85,05112877980659°) caen
exactamente en `y = 1`, la misma horizontal que la arista del polo, y el
anillo se toca a sí mismo: par-impar deja una muesca sin rellenar. Acotando a
**-85,05**, un pelo por dentro, el suelo de la costa queda en `y = 0,9999637`
y la arista del polo sigue siendo la única cosa en `y = 1`.

El hueco que eso deja es de `3,6e-5` del lado del mundo: **0,03 px** a escala
mínima en un iPhone y **1,2 px** a zoom máximo (40×). No se pierde
información: lo que hay por debajo de -85,05° Mercator no lo puede dibujar de
todas formas.

**D5 — Un vértice a |lng| = 180 con vecinos en hemisferios opuestos es un
cruce del antimeridiano, y el anillo se parte ahí.** No se puede arreglar con
D3 porque el vértice no es un extremo ambiguo: el anillo pasa de verdad de un
hemisferio al otro y necesita **dos** vértices, uno a +180 y otro a -180. Se
corta en cada cruce y cada trozo se cierra por su lado, que es el tratamiento
estándar del antimeridiano.

Encaja en tres anillos —Rusia continental, la isla de Wrangel y Fiyi—, seis
segmentos en total. El corte se hace sobre vértices que ya existen en el dato,
así que no hay que interpolar nada: el trozo hereda la latitud del vértice de
corte y solo cambia el signo de su longitud.

**D6 — Se fusiona antes de partir.** El anillo fusionado de la Antártida, una
vez desambiguado, ya no tiene ningún segmento que salte más de 180°, así que
la regla de partido lo deja intacto. Al revés no funcionaría: partir primero
rompería el arco del polo antes de poder emparejarlo con la costa.

**D7 — Los tests van sobre el asset commiteado y son invariantes, no valores
esperados.** Nada de fijar "1631 anillos": el asset se regenera y ese número
cambiaría con cualquier cambio de dataset. Lo que se fija es lo que no puede
dejar de ser cierto —ningún anillo de área cero, ningún segmento de más de
180°, relleno hasta el canto, ningún país sin anillo con área, coordenadas en
rango—. Así el test sigue valiendo si mañana se pasa a 10m.

El relleno hasta el canto se comprueba con un barrido par-impar sobre los
anillos proyectados, que es Dart puro y no necesita `dart:ui` ni un widget,
igual que `leerAnillos` en `mundo_geometria.dart`.

**D8 — Ni fusionar ni partir puede dejar puntos repetidos seguidos.** Los
anillos de world-atlas vienen cerrados explícitamente, con el último punto
igual al primero. Cortar por un vértice que es a la vez el índice 0 y el
último —o recorrer el anillo en círculo pasando por los dos— emite el mismo
punto dos veces y deja un segmento de longitud cero dentro del recorrido. Sin
filtrarlo, las reglas metían tres: dos en los cortes de Rusia y Fiyi y uno en
el empalme del anillo de Rusia continental.

Par-impar los ignora y en pantalla no se nota, que es justo el problema: es un
defecto que ningún test de relleno puede ver. Se filtran al empaquetar cada
anillo, y una invariante nueva lo fija. El cierre explícito sí se conserva:
ese punto repite al primero, no al anterior, y quitarlo cambiaría la
convención del asset para los 1631 anillos sin necesidad.

Esta decisión sale de la revisión adversarial del cambio, no del análisis
inicial.

**D9 — El umbral de área tiene cinco órdenes de magnitud de margen.** El
filtro de anillos degenerados descarta por debajo de `1e-9` grados². Medido
sobre el asset generado, el anillo legítimo más pequeño mide `8,44e-05`:
**84 000 veces el umbral**. La preocupación de que el filtro se coma una isla
pequeña queda cuantificada, y una invariante comprueba que el margen sigue
ahí si se cambia de dataset.

Por el mismo motivo, la arista polar se busca en cualquier posición del
polígono en vez de darse por hecho que es la primera: el orden de los anillos
dentro de un polígono no es algo que el formato garantice.

**D10 — El perfilado es una tarea de medida con procedimiento, no una
optimización.** Se ejecuta en perfil release-profile sobre el iPhone y se
anotan números concretos: milisegundos de *raster* por fotograma en el gesto
de zoom y en la animación del revelado, y el zoom al que la costa empieza a
verse poligonal. Con eso y solo con eso se decide si hace falta caché o si el
50m se queda corto. Si el número dice que no hace falta, este cambio cierra el
issue tal cual.

## Risks / Trade-offs

**El asset regenerado sale distinto de lo esperado** → El binario se
recommitea, así que un error se lleva a producción. Mitigación: las
invariantes de D7 corren sobre el `.bin` commiteado en cada `flutter test`, y
el número de países y el orden de los anillos se comparan con lo que había
(241 países, 1629 → 1631 anillos, 99 539 → 99 541 puntos, +24 bytes). Todo
esto ya está medido aplicando las reglas al dataset fuera de Flutter; la
implementación tiene que reproducir esos números.

**El generador descarga de la red** → `dart run tool/build_world_asset.dart`
pide el TopoJSON a jsDelivr. Si el CDN cambia o cae, no se puede regenerar.
Mitigación: ya existe `--source` para trabajar desde un fichero local, y el
`.bin` commiteado hace que ni la build ni los tests dependan de la red. Se
regenera desde un fichero descargado a mano y se deja anotado el `sha` de lo
descargado.

**La regla de fusión encaja donde no debe en un dataset futuro** → Hoy encaja
una sola vez en 241 países, pero es una regla estructural. Mitigación: el
generador registra por consola cuántos polígonos fusiona y cuántos anillos
parte, de modo que un salto en esos números al cambiar de dataset se ve al
regenerar.

**El perfilado no concluye nada** → Puede que en el iPhone del usuario no se
reproduzca el jank, o que el timeline no señale al pintor. Mitigación: se
anota igualmente lo medido. Si no hay problema de rendimiento, el issue se
cierra con las dos causas de render arregladas y la tercera descartada con
dato, que es una conclusión válida.

**Se descubre que el 50m sí se queda corto a 40×** → Sale del alcance de este
cambio y entra como delta, con el peso y el tiempo de carga del 10m medidos.
No bloquea nada de lo de aquí.

## Migration Plan

No hay migración: el formato del binario no cambia y el lector tampoco. Se
regenera el asset, se commitea y la app lo carga igual que antes. Volver atrás
es revertir el commit.

## Open Questions

- ¿Confirma el timeline en dispositivo que el coste está en el pintor del
  mundo? Se responde con la tarea de perfilado, y de la respuesta depende si
  hay delta de rendimiento.
- ¿A qué zoom empieza a verse poligonal la costa con el 50m? Se responde en la
  misma pasada y decide si hay delta de resolución.
