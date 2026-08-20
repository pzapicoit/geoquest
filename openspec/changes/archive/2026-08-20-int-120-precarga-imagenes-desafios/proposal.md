## Why

Hoy la imagen de un desafío se pide a la red la primera vez que se pinta su
pista (`_PistaImagen`) o su miniatura en el revelado (`_MiniaturaDeLaPista`):
no hay ninguna precarga. En conexiones lentas, cada parada de tipo imagen
arranca con un hueco en negro que tarda en rellenarse, y el jugador vive un
salto de carga por desafío en medio de una partida contrarreloj — justo
cuando la cuenta atrás ya está corriendo.

El intento entero (todos sus desafíos, con sus `imagen_url`) llega en una sola
respuesta de `iniciar_intento_parada` al entrar en la pantalla, así que las
URLs de las paradas 2..N se conocen mucho antes de que el jugador llegue a
ellas. Ese hueco de tiempo es gratis y hoy se desaprovecha.

## What Changes

- Al recibir el intento en `NivelJuegoScreen`, lanzar en segundo plano la
  precarga (`precacheImage`) de las `imagen_url` de **todos** los desafíos de
  tipo imagen del intento, en el orden en que se van a jugar.
- La precarga no bloquea nada: la pista del primer desafío se pinta igual que
  hoy, sin esperar al resto. No hay indicador de progreso ni estado nuevo en
  la UI.
- Un fallo de precarga (URL rota, red caída, 404) se traga en silencio: el
  desafío afectado se carga a demanda al llegar a él, exactamente como hoy,
  con su `errorBuilder` de siempre.
- La precarga se cancela implícitamente al salir de la pantalla: nada que se
  resuelva después de `dispose` toca estado ni pinta.
- Se hace inyectable el mecanismo de precarga (misma línea que `gateway`,
  `comodinesGateway`, `cargadorDeMundo` y `ahora`) para poder verificar en
  test qué URLs se piden y que un fallo no rompe la partida.

Sin cambios de esquema, de RPC ni de assets. Ningún cambio breaking.

## Capabilities

### New Capabilities
<!-- Ninguna: la precarga es comportamiento nuevo de una pantalla que ya tiene spec. -->

### Modified Capabilities
- `app-game-screen`: nuevo requirement "Precarga de las imágenes del intento" —
  al arrancar el intento la pantalla precarga las imágenes de todos sus
  desafíos sin bloquear la partida, y un fallo de precarga no altera el
  comportamiento observable (la imagen se sigue cargando a demanda).

## Impact

- `app/lib/screens/nivel_juego_screen.dart`: nuevo parámetro opcional de
  precarga en `NivelJuegoScreen`, y disparo de la precarga en
  `_alCargarElIntento` (donde ya se arranca la cuenta atrás del primer
  desafío). `_PistaImagen` y `_MiniaturaDeLaPista` no cambian: siguen usando
  `Image.network(url)`, que es lo que hace que el acierto de caché sea
  automático (mismo `NetworkImage(url)` como clave del `ImageCache`).
- `app/test/nivel_juego_screen_test.dart`: tests nuevos del disparo de la
  precarga, del orden de las URLs y de la tolerancia a fallos.
- Sin impacto en Postgres, en el panel ni en los desafíos de vídeo/texto
  (fuera de alcance por la propia historia).
- Riesgo acotado a memoria: el `ImageCache` de Flutter tiene tope propio
  (1000 imágenes / 100 MB) y un intento son pocos desafíos, así que la
  precarga no puede desbordarlo por sí sola.
