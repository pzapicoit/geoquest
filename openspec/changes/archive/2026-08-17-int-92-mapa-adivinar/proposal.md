## Why

Tras INT-91 la pantalla de juego muestra la pista del primer desafío y, al
cerrarla, revela un stub: el jugador no puede adivinar nada. Esta es la
pantalla donde realmente se juega a GeoQuest, así que hasta que exista el
mapa el juego no se puede jugar ni probar de punta a punta, y el backend
que ya calcula distancia y puntos (`responder_desafio`, INT-78) no tiene
quien lo llame.

El mapa además no es un mapa cualquiera: el diseño
(`[App] - Pantalla de juego - Mapa.dc.html` + `game-map.js`) dibuja un
mundo vectorial **sin un solo topónimo**, y eso es la mecánica del juego,
no una preferencia estética — la propia pista de texto del mockup lo dice:
*"Sin nombres en el mapa: fíate de la forma de la costa"*.

## What Changes

- **Mapa mundial vectorial a pantalla completa**, dibujado en la app desde
  geometría de Natural Earth empaquetada como asset: océano, tierra,
  fronteras y retícula, sin etiquetas, sin red y sin API key. Arrastrar
  para desplazar, pellizcar o botones +/− para el zoom.
- **Colocar pin**: tocar el mapa coloca el pin en coordenadas reales
  (proyección Mercator inversa); tocar otro punto lo reposiciona. Se
  muestra la lectura de coordenadas del pin.
- **HUD persistente** sobre el mapa, visible también con la pista abierta:
  botón de salir, nombre del nivel, "Desafío X de N" con puntitos de
  progreso, y puntaje acumulado del intento.
- **Botón "Confirmar"**, deshabilitado hasta que hay pin. Al confirmar
  llama a `responder_desafio`, suma los puntos devueltos al puntaje del
  intento y avanza al siguiente desafío mostrando su pista. El revelado
  animado del resultado (distancia, ubicación real) queda de stub para
  INT-93.
- **Botón flotante "Ver la pista"** que reabre el toast del desafío
  actual.
- **Salir (X) con modal de confirmación** que advierte de los puntos que se
  pierden; confirmar vuelve al camino de niveles.
- **BREAKING (interno)**: el toast de pista de INT-91 se rehace para
  coincidir con el diseño (kicker por tipo, caption, X de cerrar, tap en el
  fondo, animación de entrada) y deja de contener el progreso y el
  puntaje, que pasan al HUD.
- El **temporizador** que aparece en el diseño queda fuera: no tiene
  soporte en base de datos y sus reglas de juego se deciden en INT-99.

## Capabilities

### New Capabilities
- `app-world-map`: mapa mundial vectorial interactivo de la app — proyección
  y encuadre, límites de zoom y desplazamiento, colocación de pin en
  coordenadas reales y ausencia deliberada de topónimos.

### Modified Capabilities
- `app-game-screen`: la fase de mapa deja de ser un stub y pasa a ser la
  fase de adivinar (pin, confirmar, salir, reabrir pista); el progreso y el
  puntaje pasan a un HUD persistente sobre el mapa; el toast de pista
  cambia de forma; confirmar guarda la respuesta y avanza al siguiente
  desafío en vez de quedarse fijo en el primero.

## Impact

- `app/lib/screens/nivel_juego_screen.dart`: fase de mapa real, HUD
  persistente, modal de salida, avance entre desafíos.
- `app/lib/mapa/` (nuevo): proyección Mercator, cámara y pin
  (`MapaMundiController`), carga de la geometría empaquetada y el widget de
  mapa con su `CustomPainter`.
- `app/tool/build_world_asset.dart` (nuevo): genera el asset de geometría a
  partir del TopoJSON de Natural Earth.
- `app/lib/services/nivel_juego_gateway.dart`: nueva operación
  `responderDesafio(intentoId, desafioId, lat, lng)` sobre la RPC
  `responder_desafio` (INT-78), más el modelo de su respuesta.
- `app/lib/screens/camino_screen.dart`: pasa el nombre del nivel a la
  pantalla de juego.
- `app/pubspec.yaml` + `app/assets/`: geometría de Natural Earth 50m como
  asset (~700 KB).
- `app/test/`: fakes y tests de proyección, encuadre, colocación de pin,
  habilitación de "Confirmar", avance de desafío y modal de salida.
- Sin cambios de backend: `responder_desafio` ya existe y basta.
