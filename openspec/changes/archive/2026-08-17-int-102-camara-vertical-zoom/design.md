## Context

Los tres límites de la cámara del mapa se fijaron en INT-92 a partir del
mockup, antes de que hubiera nada que jugar. Con la partida completa y
probada en un iPhone real, los tres se quedan cortos o directamente enseñan
lo que no deben.

Estado actual, todo en `app/lib/mapa/mapa_mundi_controller.dart`:

```dart
double get escalaMinima => math.min(_tamano.width, _tamano.height);   // 134
double get escalaInicial => math.max(_tamano.height, escalaMinima);   // 137
double get escalaMaxima => escalaInicial * factorZoomMaximo;          // 139
static const double factorZoomMaximo = 14;                            //  88
```

`escala` es el lado en píxeles del cuadrado que ocupa el mundo entero. En un
iPhone vertical de 393×852 puntos lógicos eso da `escalaMinima = 393`: el
mundo se puede encoger hasta un cuadrado de 393×393 dentro de una pantalla de
852 de alto, o sea **459 px de franjas de fondo**, más de la mitad del
viewport. Es el "mapa cortado" del issue.

El resto del sistema ya está preparado para el cambio: `_recortarEje`,
`aplicarCamara`, `zoomEn` y `camaraPara` recortan todos contra
`escalaMinima`/`escalaMaxima`, así que mover esos dos números propaga solo.
Fuera del controlador únicamente `nivel_juego_screen.dart:211` toca la
cámara, y lo hace vía `camaraPara`.

## Goals / Non-Goals

**Goals:**

- Que no exista ninguna combinación de gestos que deje ver fondo.
- Que el jugador pueda acercarse lo suficiente para colocar el pin con
  intención, no a ojo de continente.
- Que el revelado siempre acerque, y que cuanto mejor sea la respuesta más
  de cerca se vea.
- Que la app no rote.

**Non-Goals:**

- El render del mundo en dispositivo —Antártida aplastada contra el borde,
  posible retesselación por fotograma— es INT-103. Aquí no se toca ni el
  pintor ni el asset.
- Los rótulos de los pines son INT-104.
- No se toca la coreografía del revelado: gusta como está. Cambia el
  encuadre al que lleva, no cómo llega.

## Decisions

### D1: `escalaMinima` pasa de contener el mundo a cubrir el viewport

`math.min(width, height)` → `math.max(width, height)`. Un cambio de palabra
que invierte la garantía: en vez de "el mundo entero cabe", "el área visible
está entera ocupada por mundo".

INT-92 eligió `min` a propósito, y el comentario de las líneas 131-134 lo
razona: "situarse en el globo es el primer gesto del jugador". El argumento
sigue siendo bueno, pero cuesta más de lo que vale — para ver el mundo
entero en vertical hay que sacrificar más de la mitad de la pantalla a color
de fondo. El encuadre inicial (mundo llenando la altura) ya deja ver un
hemisferio largo de un vistazo, que es suficiente para orientarse. Hay que
reescribir ese comentario, no solo el `min`: dejarlo ahí documentando la
decisión contraria a la que hace el código es peor que no tenerlo.

**Alternativa descartada:** permitir el alejado extra pero rellenar las
franjas con océano en vez de con `_fueraDelMundo`. Es maquillaje — el mundo
seguiría flotando en una banda vacía y el borde superior/inferior seguiría
delatándose al arrastrar.

### D2: `escalaInicial` desaparece

Con D1, `escalaInicial` (`max(height, escalaMinima)`) y `escalaMinima`
(`max(width, height)`) son el mismo número. Dos nombres para un valor es una
invitación a que se separen sin querer.

Se queda `escalaMinima` como único getter, `escalaMaxima` pasa a derivarse de
él y `_encuadrarDeInicio` lo usa directamente. `escalaInicial` se elimina; su
único uso fuera del controlador es
`app/test/mapa_mundi_controller_test.dart:27,345`.

**Alternativa descartada:** conservar `escalaInicial` como alias de
`escalaMinima`. Mantiene los tests intactos a cambio de dejar el concepto
duplicado en la API pública del controlador, que es justo lo que se quiere
evitar.

### D3: `factorZoomMaximo` sube de 14 a 40

Con el encuadre inicial de un iPhone (852 px de lado de mundo), el mundo a
`14×` mide 11.928 px de ancho: **3,4 km por píxel**. Un error de dedo de 10 px
son 34 km. A `40×` el mundo mide 34.080 px, **1,2 km por píxel**, y ese mismo
error de dedo son 12 km.

40 es el punto donde dejan de mandar los píxeles y empieza a mandar el
dataset. El asset es `world-atlas` 2.0.2 (Natural Earth 1:50m): su
simplificación conserva rasgos del orden del kilómetro, así que alrededor de
1 km/px es donde la costa empieza a delatarse como polígono. Subir más
requiere decidir si se pasa al 10m, y esa decisión —con el peso del asset y
el tiempo de carga sobre la mesa— es de INT-103.

Contra el sistema de puntuación esto va sobrado: con la curva de INT-101 las
3 estrellas piden ~250 km de media, o sea que 12 km de imprecisión de dedo no
mueven el resultado. El zoom no está para ganar puntos, está para que el
jugador sienta que apunta.

La tarea de implementación incluye mirar en el iPhone a `40×` si la costa
aguanta, y bajar el número si no. Queda anotado en el código el límite que se
encuentre.

**Alternativa descartada:** calcular el tope a partir del detalle real del
asset en tiempo de carga. Es una función de una variable que no cambia nunca
—el asset está commiteado— escrita como si cambiara.

### D4: el "siempre acerca" sale de D1, no de un caso especial

La tentación es meter en `camaraPara` un suelo del tipo "nunca devuelvas
menos de 1,5× la escala actual". Sería mentir sobre el encuadre: con dos
pines antipodales, acercar es incompatible con enseñarlos a los dos.

Lo que hace que el revelado acerque es D1. Antes, dos pines lejanos daban un
`camaraPara` recortado a `escalaMinima = 393` mientras el jugador miraba
desde `escalaInicial = 852`: el revelado **alejaba**, y encima destapaba las
franjas. Ahora el suelo del recorte y el encuadre de juego son el mismo
número, así que mientras los dos pines quepan el encuadre del revelado es por
construcción igual o más cercano que el de juego.

Y el caso de los pines juntos —el que motivó el issue— lo arregla D3 subiendo
el techo contra el que chocaba el encuadre.

`camaraPara` no cambia de lógica: ya calcula la mayor escala que encaja
(`math.min(ancho/tramoX, alto/tramoY)`) y ya recorta contra los límites. Lo
que cambia son los límites y, con ellos, lo que devuelve.

**Alternativa descartada:** arrancar la animación desde un encuadre más
alejado que el de juego para garantizar recorrido visible. Añade un
movimiento que nadie pidió y contradice "el efecto me gusta".

### D7: los encuadres calculados tienen su propio suelo, más bajo

Descubierto al implementar D1, y decidido con el usuario.

Al subir el suelo, el encuadre de juego pasa a abarcar solo **~166° de
longitud** (el mundo mide 852 px de lado y la pantalla 393 de ancho). Con los
márgenes del revelado —62 px a cada lado— el área útil baja a ~114°. Dos
pines más separados que eso no caben, y como `camaraPara` recorta contra
`escalaMinima`, uno se sale de la pantalla. Con una respuesta casi antipodal
—real en Nueva Zelanda, pin en España— el jugador vería un solo pin.

Es una contradicción entre dos cosas pedidas a la vez: "el mapa nunca por
debajo de llenar la altura" y "que se vean los dos pines". No se pueden
cumplir las dos en el caso extremo. **Gana que se vean los dos**: el revelado
es el momento en que la jugada se explica, y un pin fuera de pantalla lo
rompe entero; las franjas, en cambio, duran unos segundos y solo aparecen tras
un fallo catastrófico, donde además comunican bien la magnitud del error.

La implementación separa los dos suelos:

- `escalaMinima` = `max(width, height)` — el de los gestos. Es el que el
  jugador toca con el dedo y no se puede rebasar nunca.
- `escalaMinimaDeEncuadre` = `min(width, height)` — el de los encuadres
  calculados, el viejo suelo de INT-92. Solo lo alcanzan `camaraPara` y
  `aplicarCamara`, que son la vía por la que la pantalla impone un encuadre
  con el mapa ya cerrado a gestos.

El jugador no puede llegar a ese suelo con el dedo ni quedarse atrapado en
él: durante el revelado el mapa va en modo no interactivo, y pasar de desafío
llama a `reiniciarEncuadre`, que vuelve a `escalaMinima`.

**Alternativa descartada:** dejar el pin fuera de pantalla y confiar en que
la línea punteada saliendo por el borde y la hoja de resultado cuenten dónde
estaba. Ahorra las franjas a cambio de romper el único momento del juego que
tiene que funcionar sí o sí.

**Alternativa descartada:** encoger los márgenes del revelado cuando el par no
cabe. Estira el caso cómodo un poco más pero no resuelve el extremo, y mete
un encuadre de geometría variable en una animación que gusta como está.

### D5: la orientación se declara en las tres capas

`SystemChrome.setPreferredOrientations` en `main.dart` antes de `runApp`, más
la configuración nativa de cada plataforma:

- iOS: quitar `LandscapeLeft`/`LandscapeRight` de los dos arrays de
  `Info.plist` (`UISupportedInterfaceOrientations` y el `~ipad`).
- Android: `android:screenOrientation="portrait"` en la `MainActivity` del
  manifest.

Las tres hacen falta y no son redundantes: la nativa es la que gobierna el
lanzamiento, antes de que exista motor Dart, y es la única que evita el
parpadeo de arranque en apaisado. La de Flutter es la que sobrevive a un
`flutter create` que regenere plantillas.

**Alternativa descartada:** solo `SystemChrome`. Deja la app declarando ante
el sistema que soporta apaisado, con el flash de rotación en el arranque y
con el splash nativo renderizado en horizontal.

### D6: el recálculo de encuadre por cambio de tamaño se queda

`nivel_juego_screen.dart:236` recalcula el encuadre del revelado si la
pantalla cambia de tamaño a media animación, y su comentario habla de "una
rotación". Con D5 la rotación deja de ser posible, pero el cambio de tamaño
no: teclado, barras del sistema, Split View en iPad. El código se queda; el
comentario se actualiza para no prometer un caso que ya no ocurre.

## Risks / Trade-offs

**[Se pierde el "ver el mundo entero de un vistazo"]** → Es el precio
explícito de D1 y no hay mitigación que no sea maquillaje. El encuadre
inicial deja ver de sobra para orientarse, y el jugador que quiera comparar
dos continentes puede arrastrar. Si en playtesting resulta que se echa de
menos, la salida no es bajar el suelo sino un gesto de "ver todo" que
encuadre el mundo con las franjas asumidas y momentáneas.

**[A 40× la costa puede verse poligonal]** → La tarea de implementación lo
comprueba en dispositivo y baja el número si hace falta. El techo real del
asset lo mide INT-103, que puede volver a subirlo después.

**[Al mínimo zoom ahora se puede arrastrar en horizontal]** → Antes, con el
mundo más estrecho que la pantalla, el eje X quedaba centrado y bloqueado. Al
cubrir siempre, en vertical el mundo es más ancho que el viewport y el
arrastre lateral pasa a estar vivo a cualquier zoom. Es coherente con el
resto —el mundo no se repite, los bordes topan— pero es un cambio de tacto
que hay que mirar en el dispositivo.

**[Las franjas vuelven a existir, en el revelado]** → Es el precio de D7 y
está acotado: solo tras una respuesta casi antipodal, solo mientras dura el
revelado y sin que el jugador pueda provocarlas. Si en dispositivo se ve
peor de lo que suena, la salida es pintar esa franja con algo que no sea el
color de "fuera del mundo" — pero eso ya sería INT-103.

**[Tests que afirman los límites viejos]** → `mapa_mundi_controller_test.dart`
tiene expectativas literales (`escalaMinima == 390`, `escalaMaxima == 844*14`)
y `escalaInicial` desaparece. Cambian de valor, no de intención: se
actualizan en la misma tarea que el getter, y se añaden los casos nuevos que
piden las specs.

## Migration Plan

No hay migración: ningún dato persistido, ninguna API y ningún contrato con
el backend cambian. El cambio es de comportamiento en la app, y se despliega
con ella.

Orden de implementación: primero los límites del controlador con sus tests
—es lo que puede romper algo—, después la orientación, que es configuración
aislada, y al final la comprobación en iPhone real, que es la única capaz de
invalidar el 40 de D3.

## Open Questions

- El 40 de D3 es una estimación a partir de la escala del dataset, no una
  medición. Se cierra al probar en dispositivo, dentro de este cambio.
