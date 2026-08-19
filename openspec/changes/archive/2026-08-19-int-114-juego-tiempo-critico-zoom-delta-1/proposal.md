---
type: functional
parent: int-114-juego-tiempo-critico-zoom
reason: "me gusta pero redondealo con el movil xq si no se corta, puedes hacerlo un pelin pero muy poco mas gordito para que se vea y cuando haga doble clic que no ponga el punto solo haga zoom"
---

## Why

Probando INT-114 en el móvil salen tres cosas que en el emulador no se ven.

El marco de tiempo crítico se dibuja como un rectángulo recto pegado a los
cuatro cantos, y la pantalla del teléfono tiene las esquinas redondeadas: las
cuatro esquinas del marco caen fuera del área visible y **se cortan**. Con
3 px de trazo, además, cuesta verlo con el mapa a pantalla completa.

Y el doble toque, tal como lo dejó D13, **clava el pin además de acercar**. La
idea era que el pin acabase donde el jugador quería mirar de cerca, pero jugando
resulta lo contrario: "acércame aquí" y "mi respuesta es aquí" son dos
intenciones distintas, y mezclarlas pisa la respuesta que el jugador ya había
colocado con cuidado en otro sitio.

## What Changes

- **El marco sigue la forma de la pantalla.** Esquinas redondeadas y el marco
  metido unos píxeles hacia dentro, para que ningún tramo quede cortado por la
  esquina redondeada del dispositivo, sea cual sea su radio.
- **El marco engorda un pelín**: 3 → 4 px el trazo y 7 → 8 px el halo interior.
  Lo justo para que se vea sin dejar de ser un borde fino.
- **El doble toque solo acerca: no deja pin.** **BREAKING** respecto a D13 de
  INT-114. El primer toque de la pareja sigue colocando el pin al instante —eso
  no se toca—, pero al confirmarse el doble toque ese pin se deshace y se
  devuelve el mapa al pin que hubiera antes, si había alguno. Un pin colocado
  antes del gesto sobrevive al doble toque.
- Sin cambios en la cuenta atrás, ni en el umbral de zona crítica, ni en el
  factor 2× del acercamiento, ni en el backend.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities
- `app-game-screen`: la geometría del marco de tiempo crítico pasa a ser un
  borde redondeado y ligeramente metido hacia dentro, en vez de un rectángulo
  recto pegado a los cantos, y su trazo engorda.
- `app-world-map`: el doble toque deja de colocar pin. Se invierte lo que decía
  el requisito de que el segundo toque también lo coloca, y se añade que un pin
  anterior sobrevive al gesto.

## Impact

- `app/lib/screens/nivel_juego_screen.dart`: `_MarcoDeTiempoCritico` gana margen
  y radio, y sube el grosor de sus dos trazos.
- `app/lib/mapa/mapa_mundi.dart`: `_alTocar` recuerda el pin previo al primer
  toque de la pareja y lo restaura al confirmarse el doble toque. No hace falta
  API nueva en el controlador: `colocarPin` y `limpiarPin` ya existen.
- Tests: `app/test/nivel_juego_screen_test.dart` (geometría del marco),
  `app/test/mapa_mundi_test.dart` (el doble toque ya no coloca pin; el pin
  anterior sobrevive; los dos toques lejanos siguen colocando dos veces).
- `.devplugin/architecture.md`: la nota del doble toque dice hoy que el pin se
  coloca en los dos toques.
