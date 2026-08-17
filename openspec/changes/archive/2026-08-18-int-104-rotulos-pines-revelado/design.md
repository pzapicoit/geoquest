## Context

`_PinDelMapa` (`mapa_mundi.dart:279-364`) dibuja el pin dentro de un cuadro
fijo de 160×160 (`_lado`) y, si tiene `rotulo`, pinta un `Text` en mayúsculas
de 10px centrado en ese mismo cuadro, sin fondo. El nombre del pin real hoy
es el literal `'Real'`; el del jugador, `'Tu pin'`. El nombre real del sitio
(`RespuestaDesafio.nombreLugar`) ya llega a `nivel_juego_screen.dart` y hoy
solo se usa en la hoja de resultado (`_LugarRevelado`, línea 1216).

INT-102 subió el zoom máximo a 40× y cambió `camaraPara` para que el
revelado siempre acerque, así que los dos pines van a caer cerca en pantalla
con más frecuencia que antes: el diseño del rótulo tiene que asumir eso, no
tratarlo como caso raro.

## Goals / Non-Goals

**Goals:**
- El pin real muestra el nombre del sitio en vez de "Real".
- El rótulo se lee sobre cualquier fondo del mapa (tierra clara u océano).
- Un nombre largo se trunca en vez de desbordar o romper el layout.
- Los rótulos de los dos pines no se solapan entre sí, sin importar lo cerca
  que estén los pines.

**Non-Goals:**
- No se resuelve que el rótulo quede recortado por el borde de la pantalla
  cuando el pin cae muy cerca de un extremo: es una limitación preexistente
  de cualquier overlay posicionado sobre el pin y no la introduce este
  cambio.
- No se cambia la animación de entrada del pin ni su curva; el rótulo sigue
  la misma opacidad y el mismo tiempo que ya tenía.
- No se resuelve solapamiento con la hoja de resultado inferior: eso ya lo
  gobiernan los márgenes de `camaraPara` (INT-93/INT-102).

## Decisions

### D1: `revelarUbicacion` recibe el nombre como parámetro nombrado

`MapaMundiController.revelarUbicacion(Coordenada coordenada, {required
String nombre})` guarda el nombre en un campo privado `_nombrePinReal`,
expuesto como `String? get nombrePinReal`. `limpiarRevelado()` lo resetea
a `null` junto con `_pinReal` y `_progresoDeLaLinea`.

Alternativa descartada: pasar un objeto `UbicacionRevelada {coordenada,
nombre}` en vez de dos parámetros. Se descarta porque el controlador ya
expone `pin`/`pinReal` como getters sueltos (`Coordenada?`), y meter un tipo
nuevo solo para esto rompe esa simetría sin ganar nada — no hay más campos a
la vista que vayan a colgar de ese objeto.

### D2: El rótulo se dibuja en una caja propia, más ancha que el pin

Hoy el `Text` del rótulo vive dentro del `Stack` interior de `_PinDelMapa`,
acotado al ancho de `_lado` (160). Con nombres largos eso desborda. La caja
del rótulo pasa a envolverse en un `OverflowBox` con `maxWidth` propio
(200), centrado sobre el eje del pin: se permite que la píldora sea más
ancha que el cuadro de 160 sin que el layout del pin la recorte ni la
`Stack` reserve ese espacio de más.

200 es un valor fijo elegido para que quepan nombres medios sin truncar
("Torres del Paine") en el ancho típico de un iPhone en vertical, dejando
margen a los dos lados incluso con el pin centrado. No se calcula a partir
del ancho de pantalla porque `_PinDelMapa` no lo conoce y no vale la pena
pasárselo solo para esto.

Alternativa descartada: envolver todo `_PinDelMapa` en un `Positioned` más
ancho. Se descarta porque el punto de anclaje (`punto`) y el pin en sí
siguen necesitando el cuadro de 160 para su halo y su animación de entrada;
solo el rótulo necesita más sitio.

### D3: Truncado a una línea con elipsis, no envuelto a dos líneas

El rótulo usa `maxLines: 1` y `TextOverflow.ellipsis` dentro de la caja de
200px, igual que ya hace `_LugarRevelado` con el mismo nombre en la hoja de
resultado (`nivel_juego_screen.dart:1219-1220`). Mantiene el pin bajo y
legible a una sola altura de línea, sin que un nombre largo empuje el
rótulo de más arriba/abajo hacia el pin vecino ni cambie la altura reservada
según el nombre.

Alternativa descartada: dos líneas. Se descarta porque duplica la altura
que ocupa el rótulo justo en el escenario — pines cerca — donde menos
sitio vertical libre hay entre los dos, y sería inconsistente con el
truncado a una línea que ya usa el mismo nombre debajo del mapa.

### D4: Píldora de fondo, coherente con el resto de overlays del mapa

El texto se envuelve en un `Container` con `BoxDecoration`:
`color: Color(0xFF0E1620)` con alpha ~0.72 (el mismo tono y opacidad que ya
usa `_BotonesDeZoom` para su panel), `borderRadius` de píldora (999 o la
mitad del alto) y un borde de 1px blanco al 14% de opacidad. El color del
texto sigue siendo `colorDelRotulo` (el rosado del jugador o el verde-agua
del real): la píldora soluciona la legibilidad sobre el mapa, el color del
texto sigue siendo la señal que distingue un pin de otro.

### D5: El rótulo del pin del jugador sigue siendo "Tu pin"

Se mantiene el texto en vez de resolver la distinción solo por color: la
píldora ya soluciona la legibilidad, pero apoyarse únicamente en el color
para diferenciar los pines es una barrera de accesibilidad evitable (daltonismo)
que el propio issue plantea como duda. Con dos rótulos ya legibles, mantener
el texto no cuesta espacio extra que antes no se gastara.

### D6: Los rótulos no se solapan por posición fija, no por detección de colisión

`_PinDelMapa` gana un parámetro `rotuloDebajo` (`bool`, por defecto
`false`). El pin real lo deja en `false` (rótulo arriba del pin, como hoy).
El pin del jugador lo pasa a `true` **solo cuando hay pin real** (que es
además la única situación en la que hoy se le pone rótulo: ver el comentario
existente en `mapa_mundi.dart:159-160`). Con el rótulo del jugador debajo de
su pin y el del real encima del suyo, los dos rótulos quedan siempre a
lados opuestos del eje vertical de cada pin — no se solapan nunca entre sí,
sin importar la distancia en pantalla entre los dos pines.

Alternativa descartada: medir el rectángulo de cada rótulo ya renderizado y
desplazar uno si se detecta solape. Se descarta por complejidad — necesita
medir texto tras el layout y reaccionar con otro frame — para resolver un
caso que la posición fija ya cubre determinísticamente y sin parpadeo.

## Risks / Trade-offs

- [Nombres realmente larguísimos siguen truncando a algo muy corto dentro
  de 200px] → Es el mismo trade-off que ya acepta `_LugarRevelado` con el
  mismo nombre; el usuario siempre tiene el nombre completo en la hoja de
  resultado un segundo después.
- [El rótulo del jugador debajo de su pin puede quedar más cerca del borde
  inferior de la pantalla o de la hoja de resultado que antes] → Los
  márgenes de `camaraPara` para el revelado ya reservan espacio para la
  hoja inferior (`margenes.bottom`); el rótulo debajo del pin cae dentro del
  cuadro de 160 igual que antes lo hacía el de encima, solo que reflejado.

## Migration Plan

Cambio autocontenido en una sola PR: no hay estado persistido ni API externa
que migrar. `revelarUbicacion` gana un parámetro nombrado `required`, así
que el único call site (`nivel_juego_screen.dart:232`) se actualiza en el
mismo cambio y el compilador marca cualquier otro que falte.

## Open Questions

Ninguna: las dudas de diseño planteadas en el issue (D5 y D6) quedan
resueltas arriba.
