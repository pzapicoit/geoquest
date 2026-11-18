## Why

La primera pantalla que ve un jugador nuevo enseña cifras inventadas: «13 NIVELES»
y «RÉCORD 1.240» son literales en `username_screen.dart`. El camino real tiene 8
paradas, y ese récord no sale de ningún dato. Mientras carga, el splash da un
consejo de otro juego: «Acércate a menos de 30 m de cada parada para desbloquear
su pregunta», que describe una mecánica por GPS que GeoQuest no tiene.

Las dos cosas vienen del mock de Design y nunca se conectaron con datos reales.
El proyecto ya fijó el criterio en `app-login`: no se muestra ningún indicador
sin fuente de datos real, y en particular ningún récord global.

## What Changes

- Las dos insignias de la pantalla de apodo pasan a mostrar datos reales del
  camino, leídos con `CaminoGateway`:
  - **«N NIVELES»**: número de paradas;
  - **«N TEMÁTICAS»**: temáticas distintas entre esas paradas.

  El récord desaparece. Mientras carga, o si la lectura falla, las insignias no
  se muestran y se reserva su hueco para que la pantalla no salte.
- El consejo del splash se elige al azar de una lista de consejos que describen
  la mecánica real: pin en el mapa, distancia, rapidez, estrellas y comodines.
- La fila «Próximamente · Google / Apple» **se mantiene**. Está en el mock a
  propósito, va rotulada como «Próximamente» y no tiene acción, así que no
  engaña. Responde a la pregunta abierta de la issue.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

- `app-username`: nuevo requisito. Las insignias de la cabecera muestran solo
  datos reales del camino.
- `app-splash`: nuevo requisito. El consejo de carga describe la mecánica real
  del juego.

## Impact

- `app/lib/screens/username_screen.dart`: insignias con datos de `CaminoGateway`,
  inyectable.
- `app/lib/screens/login_screen.dart`: reenvía su `CaminoGateway` a
  `UsernameScreen`.
- `app/lib/screens/splash_screen.dart`: lista de consejos y elección al azar.
- Tests: `test/username_screen_test.dart`, `test/splash_screen_test.dart` y, si
  hace falta, `test/login_screen_test.dart`.
- No cambian el backend ni las dependencias. Se añade una lectura de
  `camino_jugador` en la pantalla de apodo, la misma vista que ya lee la
  bienvenida.
