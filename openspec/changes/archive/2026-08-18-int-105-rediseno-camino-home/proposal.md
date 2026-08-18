## Why

La Home del jugador (INT-90, spec `app-player-path-home`) se implementó sin
acceso al mock definitivo de Claude Design (`[App] - Camino vertical.dc.html`)
para varios detalles visuales, y se aplicaron simplificaciones deliberadas
(sin frontera "fiel" al mock final, sin animación de scroll, sin riel de
progreso). Con el mock ya localizado y leído en esta sesión, queda claro qué
diverge de la referencia y qué es un bug respecto a la propia spec vigente
(las paradas bloqueadas no se atenúan por completo). INT-105 cierra esa
brecha visual antes de seguir construyendo sobre la Home.

## What Changes

- Quitar la parada "frontera" entre temáticas: el mock de referencia no la
  contempla. **BREAKING** (para la spec `app-player-path-home`): elimina el
  requisito "Parada frontera entre temáticas consecutivas distintas" y su
  tipo `ParadaFrontera`/`intercalarFronteras` del gateway.
- Reforzar el atenuado de paradas bloqueadas: además de la portada en escala
  de grises (ya implementado), atenuar también el número de nivel, el título,
  el borde de la tarjeta y la marca del riel, igual que el mock (hoy la spec
  ya exige "gris/atenuada" de forma completa y el código solo cubre la
  portada).
- Añadir un riel de progreso vertical a la izquierda de las paradas: una
  pista de fondo sutil de extremo a extremo del camino, más un segmento
  relleno (degradado) que marca el progreso ya recorrido desde la parada
  actual hacia el nivel 1.
- Sustituir el degradado fijo de la cabecera por un desvanecido del propio
  contenido que se desplaza (máscara en los bordes superior e inferior del
  scroll), para que las tarjetas se disuelvan al pasar bajo la cabecera y el
  botón de jugar en vez de cortarse en un bloque sólido. No se añade botón de
  atrás: la Home es la pantalla raíz tras el splash y el mock tampoco lo trae.
- Añadir animación de aparición ligada al scroll: cada parada crece/se
  desvanece según su posición respecto al centro visible del camino,
  replicando la curva del mock (opacidad, escala y desplazamiento vertical
  suave cerca de los bordes superior/inferior).
- Verificar (sin cambio de código esperado, con test de regresión) que el
  orden del camino (nivel 1 abajo) y el auto-centrado en la parada actual
  siguen correctos una vez retirada la frontera.

## Capabilities

### New Capabilities

(ninguna)

### Modified Capabilities

- `app-player-path-home`: elimina el requisito de parada frontera; extiende
  el requisito de parada bloqueada para exigir atenuación completa (no solo
  la portada); añade requisito de riel de progreso vertical; añade requisito
  de animación de aparición ligada al scroll; ajusta el requisito de
  cabecera para que el desvanecido sea sobre el contenido, no un bloque fijo.

## Impact

- `app/lib/screens/camino_screen.dart`: elimina `_FronteraTile`, añade
  riel, `ShaderMask`/máscara de desvanecido y animación ligada al scroll.
- `app/lib/services/camino_gateway.dart`: elimina `ParadaFrontera`,
  `intercalarFronteras`, `_fronteraHacia`; `CaminoJugador.entradas` pasa a
  `List<ParadaCamino>`.
- `app/test/camino_gateway_test.dart`, `app/test/camino_screen_test.dart`,
  `app/test/fakes/fake_camino_gateway.dart`: se actualizan/eliminan los
  casos de frontera y se añaden los de atenuado completo y riel.
- `openspec/specs/app-player-path-home/spec.md`: vía delta de este cambio.
