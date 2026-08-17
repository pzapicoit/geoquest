## 1. Geometría del mundo como asset

- [x] 1.1 Escribir `app/tool/build_world_asset.dart`: descarga el TopoJSON de
      `world-atlas` 50m, decodifica la topología a anillos de longitud/latitud
      y emite el binario (cabecera + desplazamientos + pares `Float32`)
- [x] 1.2 Ejecutar el script y commitear `app/assets/world/world_50m.bin`,
      dejando anotado en el propio script de dónde sale el dato y su licencia
      — 241 países, 1629 anillos, 99 539 puntos, 785 KB
- [x] 1.3 Declarar `assets/world/world_50m.bin` en `app/pubspec.yaml`
- [x] 1.4 Escribir el lector del binario (`leerAnillos`/`cargarMundo`) y un
      test que compruebe que carga un número razonable de anillos y que todas
      las coordenadas caen dentro de rangos válidos

## 2. Proyección y cámara

- [x] 2.1 Implementar la proyección Mercator sobre coordenadas normalizadas
      `[0,1]²`, con la latitud acotada a ±85,051°, y su inversa
- [x] 2.2 Test puro: proyectar e invertir devuelve la coordenada de partida
      para un puñado de lugares conocidos, y la latitud fuera de rango se
      recorta
- [x] 2.3 Implementar `MapaMundiController` (`ChangeNotifier`) con escala,
      desplazamiento y pin, más `pantallaACoordenadas`,
      `coordenadasAPantalla`, `colocarPin`, `desplazar` y `zoomEn`
- [x] 2.4 Implementar el recorte de zoom: mínimo = el mundo entero cabe en
      pantalla, inicial = el mundo llena la altura, máximo = 14× la inicial
- [x] 2.5 Implementar el recorte de desplazamiento: pegado a los bordes
      cuando el mundo es mayor que el área visible, centrado cuando es menor
- [x] 2.6 Implementar la normalización de longitud a `[-180, 180]` al
      colocar pin
- [x] 2.7 Tests puros del controlador: límites de zoom, zoom alrededor de un
      punto, recorte de desplazamiento en ambos ejes, centrado, pin
      reposicionado, longitud normalizada

## 3. Widget de mapa

- [x] 3.1 `MapaMundi`: `CustomPainter` que dibuja océano, retícula generada
      en código, relleno de tierra y contorno de fronteras con los colores
      del diseño, con el grosor de línea dividido por la escala
- [x] 3.2 Construir los `Path` una sola vez al cargar y aplicar solo la
      transformación del canvas al repintar; envolver en `RepaintBoundary`
- [x] 3.3 Gestos: un `GestureDetector` con `onScaleStart/Update/End` para
      arrastrar y pellizcar, y `onTapUp` para colocar pin
- [x] 3.4 Botones de acercar y alejar sobre el mapa, que hacen zoom alrededor
      del centro y no colocan pin
- [x] 3.5 Pin como widget posicionado desde `coordenadasAPantalla`, con su
      halo en bucle y la punta anclada al punto
- [x] 3.6 Estado de carga mientras se lee el asset
- [x] 3.7 Tests de widget: un toque coloca pin, arrastrar no lo coloca,
      pulsar los botones de zoom no lo coloca

## 4. Gateway de respuesta

- [x] 4.1 Añadir `RespuestaDesafio` (distancia y puntos) y
      `responderDesafio(intentoId, desafioId, lat, lng)` a
      `NivelJuegoGateway`, sobre la RPC `responder_desafio`
- [x] 4.2 Extraer el mapeo de la fila a función pura y probarlo, igual que
      `mapearIntentoNivel`
- [x] 4.3 Extender `FakeNivelJuegoGateway` con la nueva operación:
      respuestas programables, registro de lo enviado y modo de fallo

## 5. HUD persistente

- [x] 5.1 Sacar el progreso y el puntaje de `_ToastPista` a una capa fija
      sobre el mapa, con el degradado superior del diseño
- [x] 5.2 Botón de salir (X), "Desafío X de N", nombre del nivel y píldora
      de puntaje, con la tipografía y los colores del mockup
- [x] 5.3 Barra segmentada con un segmento por desafío del intento,
      distinguiendo respondidos, actual y pendientes
- [x] 5.4 Añadir `nivelNombre` a `NivelJuegoScreen` y pasarlo desde
      `CaminoScreen` con la temática de reserva
- [x] 5.5 Tests: progreso y puntaje visibles en las dos fases, texto "Desafío
      X de N", puntaje inicial 0, reserva al nombre de la temática

## 6. Fase de adivinar

- [x] 6.1 Sustituir `_MapaStub` por el mapa real dentro de
      `NivelJuegoScreen`, conservando el toast por encima
- [x] 6.2 Botón flotante "Ver la pista" que reabre el toast sin perder pin
      ni encuadre
- [x] 6.3 Píldora de indicación: latido y "Toca el mapa para colocar tu pin"
      sin pin; icono, "Toca para ajustar" y coordenadas formateadas en grados
      con hemisferio cuando lo hay
- [x] 6.4 Botón "Confirmar": deshabilitado sin pin y mientras la llamada
      está en curso, con los dos estilos del diseño
- [x] 6.5 Confirmar llama a `responderDesafio`, suma los puntos al intento,
      avanza de desafío, limpia el pin y reabre la pista del siguiente
- [x] 6.6 Tras el último desafío, volver al camino de niveles
- [x] 6.7 Fallo al responder: aviso, pin conservado, "Confirmar" habilitado
      otra vez, sin avanzar ni cambiar el puntaje
- [x] 6.8 Tests: habilitación de "Confirmar", llamada con las coordenadas
      correctas, avance y suma de puntaje, vuelta al camino tras el último,
      y comportamiento ante fallo

## 7. Toast de pista según el diseño

- [x] 7.1 Cabecera con icono y kicker por tipo ("FOTO · PISTA 3") y botón de
      cerrar
- [x] 7.2 Fondo oscurecido que cierra al tocarlo, con su fundido de entrada
- [x] 7.3 Pie explicativo fijo por tipo de pista
- [x] 7.4 Animación de entrada de la tarjeta con la curva del mockup
- [x] 7.5 Tests: kicker correcto por tipo y posición, cierre tocando el fondo

## 8. Salida del nivel

- [x] 8.1 Modal de confirmación con el aviso de perder el intento y los
      puntos acumulados, con sus dos botones
- [x] 8.2 Seguir jugando cierra el modal sin tocar el estado; salir vuelve al
      camino
- [x] 8.3 Tests: el modal aparece, cancelar no navega, confirmar navega, y el
      texto menciona los puntos acumulados

## 9. Cierre

- [x] 9.1 Medir el coste de pintar el mundo real: 2 ms de lectura del asset,
      9 ms de construcción de los `Path` (una sola vez) y 0,03 ms por
      fotograma de grabado con 99 539 puntos. El hilo de UI no es el cuello
      de botella; la fluidez del rasterizado se confirma en dispositivo
      durante el testing local, y el plan B sigue siendo emitir dos niveles
      de detalle en el binario y elegir por escala
- [x] 9.2 `flutter analyze` y `dart format` limpios
- [x] 9.3 `flutter test --coverage` verde: 134 tests, 91,9 % de líneas en
      total y 92-100 % en todo lo nuevo
- [x] 9.4 Actualizar `.devplugin/architecture.md` con la fila de `app/`
