---
type: functional
parent: int-116-objetivo-global-nombre-corto
reason: >
  El usuario probó INT-116 en local y pidió que el toast de pista no
  revele la identidad del desafío (quién es la persona, qué monumento,
  qué película) antes de adivinar — eso lo daba `nombre` mostrado junto a
  `objetivo_global`. Pide mover `nombre` a la tarjeta de revelado, junto a
  `nombre_lugar`, en vez de mostrarlo en la pista.
---

## Why

INT-116 mostraba `nombre` (p. ej. "Charles Darwin", "Torre Eiffel") en el
toast de pista, junto al `objetivo_global` de la temática. Para las
temáticas donde la gracia del desafío es reconocer el sujeto a partir de
la imagen/vídeo (Personas de la Historia, Películas, Monumentos...),
enseñar `nombre` en la propia pista revela la respuesta antes de que el
jugador intente adivinar, vaciando de sentido el desafío.

## What Changes

- El toast de pista deja de mostrar `nombre` del desafío. Sigue mostrando
  `objetivo_global` de la temática (no revela nada específico).
- La tarjeta de revelado (tras confirmar) pasa a mostrar `nombre` del
  desafío junto a `nombre_lugar`, como el "qué era" que acompaña al
  "dónde estaba realmente".
- Sin cambios de backend: `nombre` ya viaja al cliente en
  `iniciar_intento_parada` (INT-116) y la pantalla ya conserva el
  `DesafioJuego` completo durante el revelado (`_Revelado.desafio`) — solo
  cambia qué widget de la app lo pinta y cuándo.

## Capabilities

### New Capabilities
(ninguna)

### Modified Capabilities
- `app-game-screen`: el toast de pista ya no muestra `nombre`; la tarjeta
  de revelado sí lo muestra, junto a `nombre_lugar`.

## Impact

- **App**: `app/lib/screens/nivel_juego_screen.dart` (`_TarjetaDePista` y
  `_LugarRevelado`) y sus tests en `app/test/nivel_juego_screen_test.dart`.
- Sin cambios en backend ni panel.
