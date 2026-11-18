## Why

Cada desafío da 25 s en el nivel fácil, pero el reloj arranca en cuanto aparece
la pista. Leer la pregunta y mirar la ilustración se come unos 10 s, así que
quedan unos 15 para buscar en el mapa. En una partida de prueba el reloj iba por
0:14 al pulsar «Listo, voy a adivinar». El bonus por rapidez también se mide
desde ese momento, así que leer con calma penaliza.

## What Changes

- La cuenta atrás, y la marca en el servidor desde la que se mide el bonus,
  arrancan **cuando el jugador cierra por primera vez la pista** del desafío:
  «Listo, voy a adivinar», la X o el fondo. Mientras tanto, la barra se ve
  llena y quieta.
- La pista tiene un **tope de lectura de 20 s**, visible en la tarjeta. Al
  agotarse se cierra sola y arranca el reloj. Sin tope, se podría estudiar la
  imagen indefinidamente con el reloj parado y luego contestar al instante con
  el bonus completo.
- Volver a abrir la pista con «Ver la pista», con el reloj ya en marcha, no lo
  para, igual que hoy.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

- `app-game-screen`: el requisito «Cuenta atrás visible durante la fase de
  adivinar» cambia cuándo arranca la cuenta atrás y añade el tope de lectura.

## Impact

- `app/lib/screens/nivel_juego_screen.dart`: arranque de la cuenta atrás y
  llamada a `marcarDesafioMostrado` al cerrar la pista, y tope de lectura.
- Tests de `test/nivel_juego_screen_test.dart`.
- **Sin cambios en el backend.** `marcar_desafio_mostrado` ya fija `mostrado_en`
  solo en la primera llamada (spec `challenge-timer`), y el bonus se sigue
  calculando en el servidor. Solo cambia *cuándo* llama la app. La spec
  `challenge-timer` no cambia.
- Relación con INT-139 (antitrampas): el reloj lo sigue fijando el servidor con
  `now()`. Como antes, una app modificada podría retrasar la llamada; cerrar eso
  es cosa de INT-139.
