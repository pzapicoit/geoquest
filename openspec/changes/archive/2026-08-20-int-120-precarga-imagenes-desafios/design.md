## Context

`NivelJuegoScreen` recibe el intento completo de `iniciar_intento_parada` en
una sola llamada: `IntentoNivel.desafios` trae ya la `imagenUrl` de cada
desafío. Pero la imagen no se pide hasta que se pinta el widget que la
enseña — `_PistaImagen` en el toast de pista y `_MiniaturaDeLaPista` en la
hoja de revelado—, ambos con `Image.network(url)`. El jugador paga la
latencia de red de cada imagen justo cuando llega a su parada, con la cuenta
atrás ya corriendo.

Restricciones del terreno:

- El número de desafíos por partida no es fijo: sale de
  `preguntas_por_partida` (`dificultad_defaults` o el override de la parada),
  editable desde el panel. El diseño no puede asumir "son 5".
- `precacheImage` necesita un `BuildContext`, así que la precarga vive en el
  `State` de la pantalla, no en el gateway.
- La pantalla ya tiene un patrón establecido de inyección para poder probarla
  sin salir a la red (`gateway`, `comodinesGateway`, `cargadorDeMundo`,
  `ahora`). La precarga debe seguir ese mismo patrón.
- En `flutter_test` no hay red: cualquier imagen falla. Eso condiciona cómo se
  tratan los errores (ver D4).

## Goals / Non-Goals

**Goals:**

- Que las imágenes de las paradas 2..N estén en caché antes de que el jugador
  llegue a ellas, aprovechando el tiempo que pasa jugando las anteriores.
- Coste cero para el primer desafío: ni un milisegundo más de espera ni un
  cambio visible en la pantalla.
- Un fallo de precarga es invisible: se degrada exactamente al comportamiento
  de hoy.
- Poder verificar en test qué URLs se precargan, en qué orden, y que un fallo
  no rompe la partida.

**Non-Goals:**

- Precargar vídeos (`_PistaVideo`) — fuera de alcance por la historia, y con
  un coste de red muy distinto.
- Precargar entre paradas distintas del camino, o desde la pantalla de camino.
- Cambiar el pintado de las imágenes (`_PistaImagen`,
  `_MiniaturaDeLaPista`), su `errorBuilder` o su caché: siguen igual.
- Persistir imágenes en disco entre ejecuciones de la app (`Image.network`
  usa la caché HTTP del sistema + el `ImageCache` en memoria; no se introduce
  ninguna dependencia de caché en disco tipo `cached_network_image`).

## Decisions

### D1 — La precarga se dispara en `_alCargarElIntento`

`_alCargarElIntento` es el único punto que ya se ejecuta una sola vez por
intento, con el intento en mano y con `mounted` comprobado; es donde ya se
arranca la cuenta atrás del primer desafío. La precarga se engancha ahí,
inmediatamente después.

Alternativas descartadas:

- **En `build` / dentro del `FutureBuilder`**: `build` corre muchas veces
  (cada `setState`, cada frame de la coreografía del revelado). Haría falta
  una bandera "ya precargado" para no relanzarla: estado extra por nada.
- **En `initState`**: todavía no hay desafíos; el intento no ha llegado.
- **En el gateway**: no tiene `BuildContext` y mezclaría acceso a datos con
  presentación.

### D2 — Secuencial en orden de juego, no en paralelo

El bucle precarga las URLs de una en una, esperando cada `precacheImage`
antes de lanzar la siguiente, en el orden en que se van a jugar los desafíos.

El motivo es que el problema que se está arreglando es de **ancho de banda
escaso**, no de latencia. Lanzar N descargas a la vez las hace competir entre
sí y con la del desafío que el jugador está viendo ahora mismo: en una red
lenta, en paralelo llegan todas tarde, y la primera —la única que el jugador
necesita ya— llega más tarde que hoy. En serie y en orden de juego, la imagen
que se está bajando en cada momento es siempre la siguiente que hará falta.

Trade-off aceptado: si la imagen de la parada 2 es muy pesada, las 3..N
esperan a que acabe. Es el orden correcto de prioridades — la 3 no se necesita
antes que la 2.

### D3 — La URL del primer desafío también entra en el bucle

No se salta el índice 0. `precacheImage(NetworkImage(url))` y
`Image.network(url)` comparten clave en el `ImageCache`, así que la petición
del primer desafío ya está en vuelo y la precarga se engancha a ella en vez de
duplicarla: coste real cero. A cambio, el bucle no necesita un caso especial
("empieza en 1"), y el orden de la precarga es literalmente el orden de juego.

### D4 — Los errores se tragan en dos capas, y `onError` es obligatorio

`precacheImage` **siempre** completa su `Future` con éxito: los errores los
entrega por `onError` y, si no se le pasa ninguno, los manda a
`FlutterError.reportError`. En `flutter_test` eso es un test fallado, y en
debug una pantalla roja. Como en test ninguna imagen se puede cargar, pasar
`onError` no es una precaución: es la diferencia entre que la suite pase o no.

Dos capas, entonces:

1. La implementación real pasa un `onError` que no hace nada (con el comentario
   de por qué).
2. El bucle envuelve cada llamada en `try/catch`, para cubrir un lanzamiento
   síncrono y para que un doble inyectado que lance no tumbe la partida.

Y el bucle no aborta: un fallo pasa al siguiente desafío. Una URL rota no
puede dejar sin precarga a las paradas posteriores.

### D5 — La clave de caché tiene que coincidir, así que el pintado no se toca

Lo que hace que esto funcione es que `Image.network(url)` construye
`NetworkImage(url, scale: 1.0)`, y ese objeto es la clave del `ImageCache`. La
precarga usa exactamente ese mismo provider: sin `cacheWidth`, sin
`cacheHeight`, sin `scale` propio y sin `size`. Cualquiera de esas cosas
cambiaría la clave o la decodificación y dejaría la precarga en un gasto de
red sin acierto de caché.

Corolario: `_PistaImagen` y `_MiniaturaDeLaPista` se quedan como están. Si
algún día se les añade `cacheWidth`, hay que añadírselo también aquí — queda
anotado en el código.

### D6 — Inyección por función, no por clase

`NivelJuegoScreen` recibe un parámetro opcional nuevo:

```dart
final Future<void> Function(BuildContext context, String url)? precargarImagen;
```

Con la implementación real por defecto (`precacheImage` + `NetworkImage` +
`onError` vacío). Es el mismo patrón que `ahora` (una función inyectable, no
un servicio), y por el mismo motivo: es una sola operación sin estado. Un
`ImagePrecacher` con interfaz y falso sería más ceremonia para lo mismo.

Esto es lo que hace verificables los escenarios de la spec: el test inyecta
una función que apunta las URLs recibidas (y puede lanzar a propósito) sin
tocar la red.

Alternativa descartada: no inyectar nada y comprobar el `ImageCache` global
desde el test. En `flutter_test` toda imagen de red falla, así que nunca
entraría nada en la caché y no habría forma de distinguir "precargué" de "no
precargué".

### D7 — Vida del bucle atada a `mounted`, sin cancelación explícita

Antes de cada iteración se comprueba `mounted` y se sale si la pantalla ya no
está. No hace falta más: el bucle no llama a `setState`, no toca `_indice` ni
ningún otro campo, y `precacheImage` no tiene API de cancelación. Lo que quede
en vuelo al salir acaba en la caché y se descarta solo; ninguna precarga
sobreviviente puede provocar un `setState` después de `dispose`.

`context` solo se usa mientras `mounted` es `true`, que es la condición que
Flutter exige para usar un `BuildContext` tras un `await`.

### D8 — Se saltan los desafíos sin imagen y las URLs vacías

Filtro: `tipo == TipoDesafio.imagen` y `imagenUrl` no nula ni vacía. Lo
segundo es defensivo — `_ContenidoPista` hace `imagenUrl!` y petaría antes—,
pero en un bucle de fondo lo correcto es saltar el dato malo, no reventar.

No se deduplican URLs repetidas: precargar dos veces la misma URL es un
acierto de caché la segunda vez, así que dedupe sería código sin efecto.

## Risks / Trade-offs

- **Memoria con partidas largas e imágenes pesadas** → El `ImageCache` de
  Flutter tiene tope propio (1000 imágenes / 100 MB) y evicta por LRU. Con un
  `preguntas_por_partida` alto e imágenes muy grandes podría llegar a evictar
  una imagen ya precargada antes de que el jugador llegue a ella. La
  degradación es exactamente el comportamiento de hoy (carga a demanda), que
  es justo el fallback que la spec ya admite. No se añade tope propio: sería
  un número inventado encima de uno que ya existe y funciona.
- **Consumo de datos del jugador** → Se descargan imágenes de desafíos que el
  jugador podría no llegar a ver si abandona la partida a mitad. Son las
  imágenes de una sola parada y solo tras pulsar "Jugar" (intención explícita
  de jugarla entera), así que el desperdicio máximo está acotado y es pequeño.
- **Competencia con el vídeo de un desafío de vídeo** → La precarga secuencial
  mantiene como mucho una descarga extra en vuelo, así que no puede ahogar la
  reproducción. Ir en paralelo sí podría.
- **Regresión silenciosa si alguien añade `cacheWidth` al pintado** → La
  precarga dejaría de acertar en caché sin que nada falle: solo se notaría como
  "vuelve el salto de carga". Mitigación: comentario explícito en ambos sitios
  y D5 anotado en el código.
