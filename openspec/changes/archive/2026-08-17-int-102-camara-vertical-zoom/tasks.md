## 1. Límites de la cámara

- [x] 1.1 `escalaMinima` pasa a `math.max(width, height)` en
  `app/lib/mapa/mapa_mundi_controller.dart`, y se reescribe el comentario de
  las líneas 131-134, que hoy documenta la decisión contraria de INT-92 (D1)
- [x] 1.2 Eliminar `escalaInicial`: `escalaMaxima` se deriva de
  `escalaMinima` y `_encuadrarDeInicio` la usa directamente (D2)
- [x] 1.3 `factorZoomMaximo` sube a 40, con el porqué del número —km por
  píxel y límite del dataset— en el comentario de la constante (D3)
- [x] 1.4 Revisar `_recortarEje`: con el mundo cubriendo siempre, su rama de
  "mundo más pequeño que el área visible" solo se alcanza en el eje que queda
  justo. Dejarla como está o simplificarla, pero con el comentario acorde
- [x] 1.5 Comprobar que `camaraPara` no necesita cambios de lógica y que su
  comentario de márgenes sigue siendo cierto (D4)

## 2. Orientación vertical

- [x] 2.1 `SystemChrome.setPreferredOrientations` a solo `portraitUp` en
  `app/lib/main.dart`, antes de `runApp` (D5)
- [x] 2.2 Quitar `LandscapeLeft`/`LandscapeRight` de los dos arrays de
  `app/ios/Runner/Info.plist`, incluido el `~ipad`
- [x] 2.3 `android:screenOrientation="portrait"` en la `MainActivity` de
  `app/android/app/src/main/AndroidManifest.xml`
- [x] 2.4 Actualizar el comentario de `nivel_juego_screen.dart:236`, que
  atribuye el recálculo de encuadre a una rotación ya imposible (D6)

## 3. Tests

- [x] 3.1 Actualizar las expectativas literales de
  `app/test/mapa_mundi_controller_test.dart:26-28` y la de `escalaInicial`
  de la línea 345 a los límites nuevos
- [x] 3.2 Test: alejar repetidamente deja el mundo cubriendo los dos ejes del
  área visible, sin fondo a la vista
- [x] 3.3 Test: al mínimo zoom se puede arrastrar en horizontal y los bordes
  del mundo topan sin dejar hueco
- [x] 3.4 Test: acercar repetidamente se detiene en 40 veces la escala
  inicial
- [x] 3.5 Test: `camaraPara` de dos coordenadas separadas por pocos
  kilómetros devuelve la escala máxima y las proyecta a puntos de pantalla
  distintos
- [x] 3.6 Test: `camaraPara` de un par que cabe devuelve una escala igual o
  mayor que la inicial; de un par en extremos opuestos baja hasta
  `escalaMinimaDeEncuadre` y deja los dos pines dentro de la pantalla (D7)
- [x] 3.9 Test: el gesto de alejar no alcanza `escalaMinimaDeEncuadre`, y
  `reiniciarEncuadre` deshace un encuadre que sí había bajado hasta él (D7)
- [x] 3.7 Test: un cambio de tamaño del área visible conserva el centro y
  mantiene el mundo cubriendo la pantalla
- [x] 3.8 Revisar si algún test de `app/test/mapa_mundi_test.dart` o
  `nivel_juego_screen_test.dart` depende de los límites viejos

## 4. Verificación en dispositivo

- [ ] 4.1 Probar en iPhone real: alejar al máximo en todas las pantallas con
  mapa y confirmar que no asoma fondo por ningún borde
- [ ] 4.2 Probar en iPhone real: acercar al máximo y juzgar si la costa
  aguanta a 40×; si no, bajar `factorZoomMaximo` y anotar en el comentario
  de la constante el límite encontrado (cierra la Open Question del diseño)
- [ ] 4.3 Probar en iPhone real: revelado con respuesta muy acertada (pocos
  km) y con respuesta muy lejana, confirmando que en los dos casos la cámara
  acerca y los dos pines quedan visibles
- [ ] 4.4 Probar en iPhone real: girar el dispositivo en varias pantallas y
  confirmar que la interfaz no rota, incluido el arranque
