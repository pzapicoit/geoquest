## Context

`CaminoScreen` recarga el camino en `didPopNext`, cuando vuelve a ser visible,
asignando un `Future` nuevo a `_futuro`. El `builder` del `FutureBuilder` pinta
un `CircularProgressIndicator` a pantalla completa mientras
`connectionState != done`. Al volver, por tanto, el `ScrollView` del camino se
desmonta, y cuando llegan los datos se monta uno nuevo en el offset 0. Como las
paradas se pintan de arriba (orden mayor) abajo (orden 1), el offset 0 es la
última parada.

El centrado (`_autoScroll`) solo se ejecuta una vez por vida de la pantalla:
`_autoScrolled` queda a `true` tras la primera carga y nadie lo reinicia al
volver. El botón de reintento tras error sí lo reinicia.

## Goals / Non-Goals

**Goals:**
- Al volver de jugar, ver la parada actual sin desplazarse.
- Que el riel no sugiera puntos en paradas bloqueadas.

**Non-Goals:**
- Animar el desplazamiento hacia una parada recién desbloqueada (`animateTo`).
  Un salto directo basta y es coherente con la carga inicial.
- Cambiar qué es el acumulado ni cómo se calcula (`construirCaminoJugador`).

## Decisions

**D1. Mantener los datos previos mientras se recarga.**
`FutureBuilder` conserva `snapshot.data` al cambiar de `Future`: el estado pasa a
`waiting` con los datos anteriores. El spinner pasa a pintarse solo si
`!snapshot.hasData`, es decir, en la primera carga. El `ScrollView` sigue montado
con su offset, y no hay parpadeo.
- *Alternativa:* solo reiniciar `_autoScrolled`. Arregla el centrado, pero
  mantiene el destello del spinner y un salto de offset 0 a la actual.

**D2. Reiniciar el centrado en `didPopNext`.**
`_autoScrolled = false` junto a la recarga. Con D1, el `builder` se ejecuta
primero con los datos viejos y luego con los nuevos. El reinicio tiene que
centrar con los **nuevos**, que son los que pueden traer otra parada actual. Por
eso el `builder` solo llama a `_autoScroll` cuando
`connectionState == done`.

**D3. Cifra del riel solo si la parada está desbloqueada.**
En la columna del riel, el `Text` del acumulado se sustituye por un hueco del
mismo alto cuando `desbloqueado == false`. Así la marca no cambia de sitio. La
clave `parada-puntos-<id>` deja de existir en las bloqueadas.

## Risks / Trade-offs

- [Datos viejos visibles un instante] → Es la misma información que el jugador
  veía antes de jugar; se actualiza en cuanto llega la lectura.
- [Error al recargar con datos previos] → `AsyncSnapshot.withError` no conserva
  los datos, así que sigue apareciendo `_ErrorCamino`, igual que hoy.
