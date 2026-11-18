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
volver (antes de este cambio). El botón de reintento tras error sí lo
reiniciaba.

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

**D2. Recentrar solo si cambia la parada actual.**
Con D1 el scroll ya no se pierde al volver, así que el problema original queda
resuelto sin recentrar. Recentrar siempre en `didPopNext` sería molesto, porque
también se dispara al volver de Clasificación o Comodines: el jugador perdería
la posición a la que había desplazado a mano. Por eso la pantalla recuerda en qué
parada centró (`_paradaCentrada`, anotada al programar el centrado). Con datos
definitivos (`connectionState == done`), `_autoScroll` decide por sí mismo: solo
vuelve a centrar si la `es_actual` nueva es otra, sin que el `builder` lo
decida. `_autoScroll` sigue anotando su estado al llamarse desde el `builder`,
como antes de este cambio. Es lo que pasa tras un desbloqueo.

**D2b. Spinner también en el reintento tras error.**
El spinner se pinta mientras no hay datos y la lectura no ha terminado
(`!hasData && connectionState != done`). Eso cubre la primera carga y el
reintento desde `_ErrorCamino`, que antes también lo mostraba.

**D3. Cifra del riel solo si la parada está desbloqueada.**
En la columna del riel, el `Text` del acumulado se sustituye por un hueco del
mismo alto cuando `desbloqueado == false`. Así la marca no cambia de sitio. La
clave `parada-puntos-<id>` deja de existir en las bloqueadas.

## Risks / Trade-offs

- [Datos viejos visibles un instante] → Es la misma información que el jugador
  veía antes de jugar; se actualiza en cuanto llega la lectura.
- [Error al recargar con datos previos] → `AsyncSnapshot.withError` no conserva
  los datos, así que el camino se sustituye por `_ErrorCamino` con su
  reintento, igual que antes de este cambio. Un test lo fija. Conservar el
  camino y avisar con un SnackBar queda fuera de alcance.
- [Estado del centrado tras un error] → `_autoScrolled` y `_paradaCentrada`
  sobreviven al desmontaje de la lista por error. El reintento reinicia
  `_autoScrolled`, y la pantalla de error no deja navegar, así que hoy no es
  alcanzable.
