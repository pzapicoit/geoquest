## Context

- `nivel_juego_screen.dart` (~3000 líneas) pinta cada fase con `if (...)` dentro de un `Stack`: `_ToastPista`, `_ControlesAdivinar`, `BandejaComodines`, `_HojaDeRevelado` y `_Aviso` se montan y desmontan en el mismo fotograma en que cambia el estado.
- `_ToastPista` (320 ms) y `_HojaDeRevelado` (420 ms) ya tienen entrada con `TweenAnimationBuilder`, con valores escritos a mano y sin consultar «reducir movimiento». No tienen salida.
- El revelado lo gobierna `_coreografia` (cámara, línea, contadores de distancia y puntos). La cuenta atrás y el tope de lectura son de INT-114 e INT-143. Nada de eso se toca.
- Los tests de la pantalla no pueden usar `pumpAndSettle` mientras corre la cuenta atrás (architecture.md): avanzan el tiempo con `pump`. Varios comprueban la carga con `find.byType(CircularProgressIndicator)`.
- La precarga de INT-120 exige que el pintado use exactamente `Image.network(url)`, porque el provider es la clave del `ImageCache`.
- INT-151 dejó `Movimiento`, `movimientoReducido` y `flutter_animate` (con sus valores por defecto ya tomados de `Movimiento`).

## Goals / Non-Goals

**Goals:**
- Ninguna fase entra o sale de golpe; el cambio de desafío se lee como un paso.
- Pin con caída, vibración en tres momentos y respuesta al pulsar.
- Cargas (intento e imagen) con el estilo del juego.
- Piezas reutilizables en `app/lib/motion/` para INT-153 e INT-155.

**Non-Goals:**
- **El peso de las imágenes.** Las imágenes de `challenge-media` pesan 1,1–1,8 MB (WebP sin pérdida o PNG, 1024 px). La API de transformación de Supabase exige el plan Pro, así que la solución pasa por recomprimir en `generar-imagen-lugar` y migrar las existentes. Va en una issue de backend aparte.
- Cambiar la coreografía del revelado, la cuenta atrás, el tope de lectura o la lógica de comodines.
- Sonido.
- Animaciones internas de la bandeja de comodines (abrir y plegar).

## Decisions

**D1. `Presencia`: un widget que anima la entrada y también la salida.**
`app/lib/motion/presencia.dart`: `Presencia(visible:, estilo: deslizar | fundido, retraso:, child:)`. Mientras `visible` es true pinta su hijo y lo anima hacia dentro. Cuando pasa a false, guarda el último hijo, lo anima hacia fuera y después pinta nada. Durante la salida envuelve el hijo en `IgnorePointer` y `ExcludeSemantics`: un elemento que se va no debe recibir toques ni anunciarse al lector de pantalla.
Con `movimientoReducido`, los dos estilos se quedan en un fundido.
Alternativa descartada: `AnimatedSwitcher`. Está pensado para cambiar un hijo por otro en el mismo hueco. Aquí cada fase ocupa su capa del `Stack` y lo que hace falta es entrar y salir de forma independiente.

**D2. El cambio de desafío es solo visual: la lógica no se retrasa.**
`_avanzarDesdeElRevelado` sigue cambiando el estado en el mismo instante que hoy. La hoja sale gracias a que `Presencia` guarda su último hijo, y la tarjeta de pista del siguiente desafío entra con `retraso: Movimiento.media`. Retrasar la lógica cambiaría cuándo se prepara la cuenta atrás (INT-143) para ganar solo unos milisegundos de efecto.
Consecuencia: el tope de lectura del siguiente desafío empieza a correr unos 300 ms antes de que se vea la tarjeta. Se acepta frente a 20 s de tope; se anota en riesgos.

**D3. Caída del pin en `_PinDelMapa`, que se rehace con cada coordenada nueva.**
`_PinDelMapa` envuelve su dibujo en un `TweenAnimationBuilder` con `key: ValueKey(coordenada)`, así que la animación vuelve a empezar cada vez que el pin se mueve. La caída son 18 px hacia abajo con una escala de 0,7 a 1, en `Movimiento.media` con `Movimiento.rebote`. Con «reducir movimiento» aparece directamente, sin animación.
Solo cae el pin del jugador. El pin real lo presenta la coreografía del revelado, que no se toca.

**D4. Vibración con `HapticFeedback`, sin dependencias.**
- Pin: `selectionClick` en el manejador de toque de `MapaMundi`, cuando `colocarPinEn` devuelve true.
- Confirmar: `mediumImpact` al empezar `_confirmar` y `_confirmarSinPin` solo si es un toque del jugador. La confirmación automática por tiempo agotado no vibra, porque el jugador no ha hecho nada.
- Éxito: `heavyImpact` una sola vez por revelado, cuando `_avanceDeLosPuntos` llega a 1 con `puntos > 0`. Se controla con un flag en `_Revelado`. Flutter no expone el patrón «success» de iOS; `heavyImpact` es lo más parecido sin añadir un plugin.
En web `HapticFeedback` no hace nada. Los tests interceptan la llamada `HapticFeedback.vibrate` del canal `SystemChannels.platform`.

**D5. `Pulsable`: escala al pulsar con un `Listener`.**
`app/lib/motion/pulsable.dart`: `Pulsable(habilitado:, child:)` escucha `onPointerDown`/`Up`/`Cancel` con un `Listener`, que no compite con los reconocedores de gestos del botón, y anima la escala a 0,96 en `Movimiento.rapida`. Deshabilitado, no reacciona. Con «reducir movimiento» tampoco escala: la respuesta visual la siguen dando el propio botón y la vibración.

**D6. Carga del intento: `_CargandoIntento`.**
Sustituye el `CircularProgressIndicator`. Muestra el logo de marca (`assets/branding/geoquest-logo.png`) con un pulso suave y el texto «Preparando el nivel…». Lleva `Key('nivel-juego-cargando')` y una etiqueta semántica para el lector de pantalla. Con «reducir movimiento» queda quieto.
Los tests que buscaban `CircularProgressIndicator` pasan a buscar esa clave. El indicador de «Ver resultados» de la hoja y el del vídeo se quedan como están: son esperas dentro de un botón o de un reproductor, no la carga de la pantalla.

**D7. Imagen con `frameBuilder`, sin cambiar el provider.**
`_PistaImagen` y `_MiniaturaDeLaPista` siguen siendo `Image.network(url)`; solo se añade `frameBuilder`:
- `wasSynchronouslyLoaded` (acierto de caché por la precarga): devuelve la imagen tal cual, sin fondo ni fundido.
- Si no: apila `FondoDeCarga` (nuevo, `app/lib/motion/fondo_de_carga.dart`: un brillo que barre en bucle, o quieto con «reducir movimiento») y la imagen con `AnimatedOpacity` de 0 a 1 en cuanto llega su primer fotograma.
El `errorBuilder` no cambia. El test de INT-120 que compara providers sigue valiendo.

**D8. Las entradas que ya existían pasan a la base común.**
La entrada de `_ToastPista` y la de `_HojaDeRevelado` pasan a `Presencia` con `Movimiento.media`/`Movimiento.pantalla` y `Movimiento.llegada`, en vez de sus `TweenAnimationBuilder` con valores propios. El fundido del fondo oscuro de la pista acompaña a la tarjeta en la entrada y en la salida.

## Risks / Trade-offs

- [Los tests que esperan que un elemento desaparezca tras un solo `pump` fallarán, porque ahora sale animado] → Se ajustan para avanzar `Movimiento.media` antes de comprobar. Se revisan con la suite completa; ningún test se borra.
- [Un elemento saliente sigue en el árbol unos 300 ms] → `IgnorePointer` y `ExcludeSemantics` evitan toques dobles (por ejemplo, Confirmar dos veces) y anuncios duplicados. Hay un test que pulsa durante la salida.
- [El tope de lectura empieza ~300 ms antes de que se vea la pista del siguiente desafío (D2)] → Despreciable frente a 20 s; se documenta. Si en la prueba se nota, el retraso de entrada se baja a `Movimiento.rapida`.
- [`FondoDeCarga` en bucle mientras una imagen no llega] → Se desmonta en cuanto llega el primer fotograma o salta el `errorBuilder`, y con «reducir movimiento» no anima.
- [La vibración puede resultar excesiva] → Solo en tres momentos y nunca en bucle. Se valida en el iPhone durante la prueba local.

## Migration Plan

Solo cliente. Revertir el cambio devuelve la pantalla al comportamiento de INT-151, sin datos que migrar.

## Open Questions

- Abrir una issue de backend para recomprimir las imágenes de `challenge-media` (WebP con pérdida, ~100–200 KB) y migrar las existentes. Se propone al usuario junto con esta propuesta.
