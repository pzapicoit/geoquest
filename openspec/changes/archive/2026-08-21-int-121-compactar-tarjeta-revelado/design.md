## Context

`_HojaDeRevelado` (en `app/lib/screens/nivel_juego_screen.dart`) es la hoja
que sube desde abajo al revelar un desafío. Hoy encadena, de arriba abajo:
miniatura + `_LugarRevelado` (nombre, rótulo "UBICACIÓN REAL", lugar y
coordenadas), las tarjetas de distancia y puntos (`_TarjetaDeDistancia` /
`_TarjetaDePuntos`, esta última con el número grande y "/ máximo" debajo),
`_DesgloseDePuntaje` (precisión y bonus apilados), el botón de continuar y,
por último, un `TextButton` de "Repetir animación".

Esa hoja no solo ocupa pantalla: también decide el encuadre. La coreografía
del revelado encuadra los dos pines dentro del área útil que calcula
`_margenesDelRevelado`, que reserva abajo `alto * 0.48` "para la hoja de
resultado". Es decir, cada píxel de hoja que se quita es mapa que se puede
recuperar dos veces: el que la hoja deja de tapar y el que el encuadre deja
de reservar.

Restricciones del proyecto que condicionan el cómo:

- La hoja se repinta en cada fotograma de la coreografía (está dentro de un
  `AnimatedBuilder` sobre `_coreografia`): nada de la poda puede introducir
  medidas costosas ni estado nuevo.
- Los `Key` de los widgets son el contrato con los tests de widget: quitar un
  elemento es quitar su key, y unir dos textos no debe cambiar su copy si se
  quiere conservar las aserciones existentes.
- `resumen_nivel_screen.dart` tiene su propio "Repetir animación"
  (`resumen-nivel-repetir`), que esta historia no toca.

## Goals / Non-Goals

**Goals:**

- Bajar la altura de la hoja de resultado de forma apreciable quitando cuatro
  elementos que no aportan a la lectura del resultado.
- Que el encuadre del revelado aproveche el mapa que la hoja libera.
- Conservar la jerarquía visual: lugar → distancia → puntos → continuar.
- Dejar el cambio cubierto por tests de widget que fallen si alguno de los
  elementos podados vuelve, y que vigilen que la franja reservada sigue
  cuadrando con la hoja.

**Non-Goals:**

- Tocar el cálculo de puntos, precisión o bonus, ni el contrato de
  `responder_desafio`: `puntos_maximos` sigue llegando y sigue parseándose,
  solo deja de pintarse (queda sin consumidor de UI, a propósito: el parseo
  estricto es el que avisa si el RPC cambia).
- Rediseñar la hoja más allá de la poda: mismos colores, mismos tamaños de
  fuente, mismas tarjetas.
- Tocar el "Repetir animación" del resumen de nivel.
- Cambiar el comportamiento de los desafíos sin pin (INT-99) más allá de lo
  que se ajuste solo al quitar estos elementos.

## Decisions

### D1. Quitar el botón, no esconderlo

El `TextButton` de "Repetir animación" y el parámetro `onRepetir` de
`_HojaDeRevelado` desaparecen; `_lanzarElRevelado` se queda tal cual, porque
sigue siendo el punto de entrada de la coreografía al confirmar (L520) y al
agotarse el tiempo (L558). Solo hay que ajustar su comentario, que hoy dice
"Lanza —o relanza— la coreografía".

Alternativa descartada: dejar el parámetro `onRepetir` opcional para poder
resucitar el botón. Un parámetro sin uso es código muerto que el analyzer no
marca (es un campo público de un widget privado) y que el siguiente que lea
la clase tendrá que rastrear.

### D2. `_TarjetaDePuntos` pierde el parámetro `maximo`

Al quitar la línea "/ máximo", `maximo` deja de usarse en el widget, así que
sale de su constructor y de las dos llamadas (caso con y sin distancia). Así
el widget no miente sobre lo que necesita, y `revelado.respuesta.puntosMaximos`
queda referenciado solo donde de verdad se muestra.

Con eso `RespuestaDesafio.puntosMaximos` se queda sin ningún consumidor de
UI. Se mantiene igual: el RPC lo devuelve, el mapeo del modelo lo lee de forma
estricta y es ese parseo el que avisaría de un cambio de contrato. Borrarlo
sería alejar el modelo de la respuesta que documenta `challenge-scoring`.

Efecto lateral buscado: las dos tarjetas de la fila (distancia y puntos)
pasan a tener la misma altura natural, porque la de puntos ya no lleva una
línea extra debajo del número. El `IntrinsicHeight` que las iguala se queda:
sigue haciendo falta porque la cabecera "TE HAS DESVIADO" puede partirse en
dos líneas con fuentes grandes.

### D3. Precisión y bonus en una línea, con `Wrap`

`_DesgloseDePuntaje` pasa de `Column` a `Wrap` (`spacing` horizontal,
`runSpacing` pequeño) con tres hijos: el texto de precisión, un separador
"·" y el texto de bonus — los dos últimos solo cuando `puntosBonus > 0`.

Por qué `Wrap` y no `Row`: con un `Row` habría que elegir entre desbordar
(overflow) o recortar con `ellipsis`, y con las fuentes de accesibilidad
grandes de iOS/Android el recorte se comería justo la cifra. `Wrap` cae a dos
líneas en ese caso extremo —exactamente lo que hay hoy— y en el caso normal
deja la línea única que pide la historia. La cadena más larga realista
("5.500 puntos de precisión · +500 por rapidez") cabe de sobra en los 350 px
útiles de un móvil de 390 px.

Con la Outfit real la cadena más larga ronda 310 px de los ~350 útiles: cabe,
pero justo, y por eso el repliegue importa. En `flutter_test` no cabe nunca
—la fuente de test pinta cada glifo como una caja del tamaño de la fuente, así
que las mismas cadenas ocupan ahí casi el doble—, así que el test de "misma
línea" corre a 900 px de ancho: lo que verifica es la dirección del `Wrap`,
que es lo que un `Column` nunca cumpliría a ningún ancho.

Se conservan las keys `nivel-juego-puntos-precision` y
`nivel-juego-puntos-bonus` y el copy exacto de cada texto, de forma que los
tests que buscan "4.301 puntos de precisión" y "+80 por rapidez" siguen
valiendo y solo hay que añadir la aserción de que comparten línea.

El separador va como `Text` propio en vez de pegado a uno de los dos textos
para no cambiar su copy. Contrapartida aceptada: si `Wrap` reparte en dos
líneas, el "·" se queda al final de la primera. Es un caso de fuente
gigante y no justifica complicar el widget.

### D4. Las coordenadas se van de la hoja, `formatearCoordenadas` se queda

`_LugarRevelado` pierde su último `Text` (y el `SizedBox` de 3 px que lo
separaba). `formatearCoordenadas` sigue usándose en el chip del pin del
jugador durante la fase de adivinar (L1546), así que no se toca la función ni
sus tests.

### D5. El margen inferior del encuadre se recalcula midiendo, no a ojo

Medido a 390×844 en el caso más alto (con pin: miniatura + lugar + las dos
tarjetas + desglose + botón), la hoja ocupa **465 px antes de la poda y 373
después** (55 % → 44 % de la pantalla).

Ese número desmiente la intuición de partida: la franja de hoy (`alto * 0.48`
= 405 px) no reserva de más, **reserva de menos** — se queda ~60 px corta con
la hoja actual, y ~94 px si el móvil tiene barra inferior del sistema, porque
el `SafeArea` de la hoja la hace más alta justo eso. Es decir, hoy el encuadre
puede colocar un pin en una franja que la hoja tapa, contra lo que pide el
propio requirement ("con margen para que ninguno quede tapado").

Así que el margen no baja para "recuperar mapa" —eso ya lo da la poda de la
hoja— sino para dejar de mentir:

    margen inferior = alto * fraccionDeLaHojaDeRevelado
                    + MediaQuery.paddingOf(context).bottom

`fraccionDeLaHojaDeRevelado` es 0.46 — 388 px de 844: cubre los 373 medidos
con 15 px de holgura para las diferencias de métrica de fuente entre
plataformas (en `flutter_test` los glifos son cajas del tamaño de la fuente,
así que la medida de 373 es de las altas: en un móvil real el desglose cabe en
una línea y la hoja sale algo más baja). Es una constante pública del fichero
—como `formatearPuntaje` y compañía— porque el test de guardia (D6) mide
contra ella: con el número copiado en el test, cambiar el factor en un solo
lado pasaría de largo.

La barra inferior se suma aparte, en píxeles, porque es lo que crece la hoja
por su `SafeArea`: meterla en la proporción castigaría a los móviles que no la
tienen. Se lee de `MediaQuery.paddingOf` y no de `viewPaddingOf` porque
`padding` es exactamente lo que consume ese `SafeArea` (con el teclado
abierto, `padding.bottom` cae a 0 y el `SafeArea` deja de reservarlo;
`viewPadding` seguiría diciendo 34 y el encuadre reservaría de más).

Leer el `MediaQuery` en ese getter no registra dependencia, porque no se llama
desde un `build`. Para que eso no se convierta en un encuadre obsoleto, el
valor usado queda apuntado en `_barraInferiorDelRevelado`, al lado del
`_tamanoDelRevelado` que ya existía, y `_alAvanzarLaCoreografia` recalcula el
encuadre si cualquiera de los dos cambia a media coreografía (un Split View,
o Android pasando de barra de navegación a gestos).

Alternativa descartada: medir la hoja en tiempo de ejecución (`GlobalKey` +
`RenderBox`, o un `LayoutBuilder` que informe hacia arriba) y usar esa altura
como margen exacto. Es lo "correcto" pero pide medir dentro de la coreografía
que se está animando y un fotograma extra de reencuadre; para una hoja cuya
altura es prácticamente fija no vale la complejidad ni el riesgo de pelearse
con `aplicarCamara`.

### D6. La franja reservada se vigila con un test de tamaño, no con un grep

El test de guardia mide la hoja renderizada
(`tester.getSize(find.byKey(Key('nivel-juego-revelado')))`) a 390×844, en el
caso más alto, y comprueba dos cosas contra la franja de 388 px: que cabe
dentro (no la desborda, que es el fallo que había hasta ahora) y que la
diferencia es menor de 45 px (que la franja no se quedó de más). Así el
guardia falla tanto si la hoja vuelve a crecer como si alguien vuelve a subir
el factor sin motivo, y no depende de leer el fuente. La franja del test se
calcula con la constante del código (`844 * fraccionDeLaHojaDeRevelado`), no
con el número a mano.

## Risks / Trade-offs

- [Perder el "/ máximo" quita la referencia de cuánto se podía sacar] → Es
  una decisión de producto de la propia historia; el máximo por desafío sigue
  siendo el mismo para todos los jugadores y el resumen del nivel mantiene la
  referencia agregada (umbral para superar y estrellas). Si se echa en falta,
  vuelve como delta.
- [Sin "Repetir animación" no hay forma de volver a ver la coreografía] → La
  secuencia dura ~5 s y termina en el mismo estado que deja en pantalla
  (pines, línea, cifras finales), así que no hay información que se pierda al
  no poder repetirla.
- [El desglose en una línea puede replegarse a dos con fuentes de
  accesibilidad grandes] → Aceptado y buscado (D3): es el comportamiento de
  hoy, no una regresión, y es preferible a recortar la cifra.
- [Tocar el margen del encuadre cambia cómo se ve el revelado en todos los
  desafíos] → El margen nuevo se deriva de la altura medida de la hoja y, a
  diferencia del de antes, la cubre: en un móvil con barra inferior reserva
  algo más que hoy (422 px frente a 405) y en uno sin ella algo menos (388).
  El test de guardia (D6) comprueba que la franja sigue cubriendo la hoja, y
  los escenarios de encuadre existentes (respuesta muy acertada, muy lejana,
  cambio de tamaño a media animación) siguen en verde.
- [Los tests que se caen podrían esconder cobertura perdida] → El test
  "repetir la animación no vuelve a llamar al servidor" cubría, de paso, que
  la coreografía no llama dos veces al servidor. Esa garantía la siguen dando
  los tests de `respuestasEnviadas, hasLength(1)` del revelado normal, así que
  el test se borra en vez de reescribirse.

## Open Questions

- Ninguna. El factor del margen salió de medir la hoja (D5), no de una
  decisión pendiente.
