## 1. Reglas de geometría en el generador

- [x] 1.1 En `app/tool/build_world_asset.dart`, añadir el cálculo de área de
      un anillo (fórmula del cordón de zapato) y un predicado de
      antimeridiano (`|lng| == 180`)
- [x] 1.2 Implementar la fusión del polígono de cierre polar (D2): si el
      anillo exterior de un polígono encierra área cero, concatenar todos sus
      anillos en uno solo
- [x] 1.3 Dentro de esa fusión, desambiguar el lado del ±180 de cada extremo
      por el signo de su vértice vecino (D3), y acotar la costa a -85,05°
      (D4). No aplicar la desambiguación fuera del polígono fusionado
- [x] 1.4 Implementar el partido en el antimeridiano (D5): un vértice a
      |lng| = 180 con vecinos en hemisferios opuestos corta el anillo, y cada
      trozo se cierra con su extremo en su lado del antimeridiano
- [x] 1.5 Encadenar las dos reglas en `_decodificarPaises` con la fusión
      antes del partido (D6), y descartar los anillos que queden con menos de
      tres puntos
- [x] 1.6 Registrar por consola cuántos polígonos se fusionan y cuántos
      anillos se parten, junto al resumen que ya imprime
- [x] 1.7 Filtrar los puntos que repiten al anterior al empaquetar cada
      anillo (D8): cortar por un vértice que el dato ya traía duplicado deja
      un segmento de longitud cero dentro del recorrido
- [x] 1.8 Buscar la arista polar en cualquier posición del polígono en vez de
      dar por hecho que es la primera (D9)

## 2. Regeneración del asset

- [x] 2.1 Descargar el TopoJSON de `world-atlas@2.0.2` a un fichero local y
      anotar su `sha256` en el comentario de cabecera del generador
- [x] 2.2 Regenerar con `dart run tool/build_world_asset.dart --source <fichero>`
      y comprobar que la consola dice 1 polígono fusionado y 3 anillos
      partidos
- [x] 2.3 Verificar los números contra lo medido en el diseño: 241 países,
      1631 anillos, 99 541 puntos, +24 bytes respecto al asset actual
- [x] 2.4 Commitear `app/assets/world/world_50m.bin` regenerado

## 3. Tests de invariantes sobre el asset

- [x] 3.1 En `app/test/mundo_geometria_test.dart`, test: ningún anillo del
      asset commiteado encierra área cero
- [x] 3.2 Test: ningún segmento de ningún anillo separa sus extremos más de
      180° de longitud
- [x] 3.3 Test: barrido par-impar sobre los anillos proyectados a la altura
      del canto inferior — el relleno de tierra ocupa prácticamente todo el
      ancho, sin banda de océano bajo la tierra más austral (Dart puro, sin
      `dart:ui`)
- [x] 3.4 Test: los 241 países siguen ahí y cada uno conserva al menos un
      anillo con área
- [x] 3.5 Test: todas las latitudes en `[-90, 90]` y todas las longitudes en
      `[-180, 180]`
- [x] 3.6 Test: ningún anillo repite un punto dentro del recorrido, y el
      test falla con el asset que sí los traía
- [x] 3.7 Test: el anillo legítimo más pequeño está muy por encima del umbral
      con el que se descartan los degenerados (D9)
- [x] 3.8 `flutter test` en verde y cobertura sin bajar

## 4. Perfilado en dispositivo (medida, no optimización)

- [ ] 4.1 Compilar en modo profile y arrancar en el iPhone real con INT-102
      dentro: `flutter run --profile -d <iphone>`
- [ ] 4.2 Con el DevTools timeline abierto, grabar un gesto de zoom completo
      de mínimo a máximo y anotar el peor tiempo de *raster* y de *UI* por
      fotograma
- [ ] 4.3 Grabar la animación del revelado con dos pines lejanos y anotar lo
      mismo
- [ ] 4.4 Anotar a qué zoom empieza a verse poligonal la costa con el asset
      50m, dentro del rango hasta 40× que dejó INT-102
- [ ] 4.5 Volcar las tres medidas en `.devplugin/architecture.md`, y en el
      issue de Linear con captura del timeline

## 5. Verificación

- [ ] 5.1 Capturar el mapa en el iPhone y comprobar que no hay corte en la
      Antártida, ni raya pegada al canto inferior, ni rayas cruzando el mapa
      por el Ártico, el Pacífico o el Índico
- [ ] 5.2 Comprobar que Rusia y Fiyi siguen dibujándose completos a los dos
      lados del meridiano 180
- [ ] 5.3 Decidir, con las medidas de la sección 4 delante, si hace falta un
      delta de rendimiento o de resolución del asset, y dejarlo dicho en el
      issue
