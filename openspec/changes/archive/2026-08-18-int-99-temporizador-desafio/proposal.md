## Why

El diseño de la pantalla de juego incluye una cuenta atrás por desafío —
barra que pasa de teal a ámbar y a rojo, 60 s por defecto— que hoy no existe
en el backend: `respuestas_desafio` no guarda tiempo, `niveles` no tiene
ninguna columna de segundos y `calcular_puntaje` solo mira la distancia. Sin
esto la partida no tiene presión de tiempo y la pantalla de juego (INT-92)
no puede implementar el HUD tal y como está diseñado.

## What Changes

- Cada nivel define sus segundos por desafío (`niveles.segundos_por_desafio`,
  60 s por defecto).
- El servidor registra cuándo se muestra cada desafío de un intento (nueva
  RPC `marcar_desafio_mostrado`) para medir el tiempo transcurrido sin
  fiarse del reloj del cliente.
- El puntaje de un desafío incorpora un bonus por rapidez además de la
  distancia. El máximo por desafío sube de 5000 a 5500 puntos.
  **BREAKING**: cambia la firma de `calcular_puntaje` (pasa a recibir el
  tiempo transcurrido y el límite del nivel, no solo la distancia).
- `responder_desafio` acepta coordenadas ausentes: si el tiempo se agota sin
  pin colocado, se registra una respuesta de 0 puntos sin coordenadas.
  **BREAKING**: cambia la firma de `responder_desafio` (los parámetros de
  latitud/longitud admiten `null`) y `lat_adivinada`/`lng_adivinada`/
  `distancia_km` de `respuestas_desafio` pasan a ser opcionales.
- Se rebalancean `umbral_estrella_1/2/3` y `puntaje_minimo_superar` de los
  niveles ya existentes (×1.1) para conservar su dificultad relativa con el
  nuevo máximo por desafío.
- La app muestra una barra de cuenta atrás en el HUD (verde → ámbar → rojo)
  durante la fase de adivinar, con auto-confirmación del pin colocado al
  llegar a 0 y registro de "tiempo agotado" si no hay pin.
- El revelado desglosa el puntaje del desafío en precisión + bonus por
  rapidez (p. ej. "+80 por rapidez"), en vez de mostrar solo el total.
- El panel gana un campo para configurar los segundos por desafío de cada
  nivel, y su cálculo de "distancia media" por umbral pasa a asumir el peor
  caso (sin bonus de tiempo).

## Capabilities

### New Capabilities
- `challenge-timer`: configuración del límite de tiempo por nivel, marcado
  del inicio de cada desafío, cálculo del tiempo transcurrido en el
  servidor y comportamiento al agotarse (con o sin pin colocado).

### Modified Capabilities
- `game-data-model`: nuevas columnas de tiempo en `niveles`,
  `intento_desafios` y `respuestas_desafio`; coordenadas y distancia pasan a
  ser opcionales en `respuestas_desafio`; excepción controlada a la
  prohibición de `update` sobre `intento_desafios`.
- `challenge-scoring`: el puntaje por desafío incorpora un bonus por
  rapidez sobre la curva de distancia existente; `responder_desafio` acepta
  coordenadas ausentes.
- `app-game-screen`: cuenta atrás visible en el HUD, marcado de inicio de
  desafío, auto-confirmación al agotar el tiempo y registro de "tiempo
  agotado" sin pin.
- `panel-level-detail`: campo de segundos por desafío en la configuración
  del nivel; el cálculo de distancia media por umbral pasa a asumir el peor
  caso.

## Impact

- Backend: nueva migración SQL (esquema + funciones + rebalanceo de datos
  existentes); cambia la firma de `calcular_puntaje` y de
  `responder_desafio`; nueva RPC `marcar_desafio_mostrado`.
- Panel: `panel/src/lib/nivelRecorrido.ts` y `panel/src/pages/NivelRecorrido.tsx`
  (nuevo campo, `MAX_PUNTOS_DESAFIO` pasa de 5000 a 5500, cálculo de
  distancia media ajustado).
- App (Flutter): `nivel_juego_gateway.dart` (parámetros opcionales, nueva
  llamada RPC), `nivel_juego_screen.dart` (temporizador visual,
  auto-confirmación, aviso de tiempo agotado).
