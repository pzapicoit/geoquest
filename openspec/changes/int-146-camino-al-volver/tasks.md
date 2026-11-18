## 1. Centrado al volver

- [x] 1.1 Tests en rojo en `camino_screen_test.dart`: tras volver de una ruta empujada encima, el scroll queda centrado en la parada `esActual` (no en offset 0); si la recarga trae otra parada actual, se centra en la nueva; durante la recarga no aparece el spinner
- [x] 1.2 `builder`: spinner solo sin datos previos; `_autoScroll` solo con `connectionState == done`
- [x] 1.3 `didPopNext`: reiniciar `_autoScrolled` junto a la recarga

## 2. Riel sin cifras en paradas bloqueadas

- [x] 2.1 Tests: las paradas bloqueadas no muestran `parada-puntos-*`; las desbloqueadas sin jugar siguen repitiendo el acumulado anterior; con la última desbloqueada, coincide con la barra superior
- [x] 2.2 Columna del riel: hueco del mismo alto en vez de la cifra cuando `desbloqueado == false`

## 3. Cierre

- [x] 3.1 `flutter analyze`, `dart format` y `flutter test` en verde
- [x] 3.2 Prueba en web con Chrome DevTools: jugar el nivel 1, «Volver al camino» y ver la parada actual centrada y el riel sin cifras en las bloqueadas
  - Hecha el 2026-11-18 contra `flutter run -d web-server` con un script de Playwright y el Chrome del sistema (390×844, contexto limpio): el Chrome DevTools de ECC se desconectó en la sesión. Entra como invitado, abre el nivel 1, sale con «Salir y perder el intento» y vuelve al camino. Al volver, la parada 1 (`es_actual`) queda centrada sobre el botón de jugar, no la 8 arriba del todo. En el riel solo la parada 1 muestra cifra («0»); las bloqueadas conservan su marca atenuada, sin número.
