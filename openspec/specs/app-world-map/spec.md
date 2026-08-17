# app-world-map Specification

## Purpose

El mapa mundial sobre el que el jugador marca su respuesta: cómo se dibuja,
cómo se navega y cómo un toque en pantalla se convierte en una coordenada
real. Su rasgo definitorio es lo que **no** tiene — ningún topónimo —, porque
adivinar en GeoQuest consiste en reconocer la forma del terreno.
## Requirements
### Requirement: El mapa dibuja el mundo sin ningún topónimo

El mapa de juego SHALL dibujar el mundo a partir de geometría vectorial
empaquetada en la app (fronteras de países, masas de tierra y retícula de
meridianos y paralelos), sin nombres de países, ciudades, mares ni
ningún otro rótulo, y sin depender de un servicio de teselas en red.

Adivinar en GeoQuest consiste en reconocer la forma del terreno: un
rótulo visible convertiría cualquier desafío en una lectura, no en una
deducción.

Los únicos textos que pueden aparecer sobre el mapa SHALL ser los de los
pines —"tu pin" y el de la ubicación real del revelado—, que no nombran
ningún lugar del mundo.

#### Scenario: El mapa se dibuja sin conexión a la red

- **WHEN** el jugador entra a la fase de mapa sin conexión a internet
- **THEN** el mapa se dibuja igualmente con la geometría empaquetada en la
  app, sin mensajes de error de mapa y sin peticiones a ningún servidor de
  teselas

#### Scenario: El mapa no rotula ningún lugar

- **WHEN** se inspecciona lo que el mapa dibuja a cualquier nivel de zoom
- **THEN** no aparece ningún texto que nombre un lugar: solo relleno de
  tierra, contorno de fronteras, océano, retícula y, si hay pines, sus
  rótulos

### Requirement: Tocar el mapa coloca el pin en coordenadas reales

El mapa SHALL convertir el punto tocado en pantalla a latitud y longitud
reales mediante la inversa de su proyección, y colocar allí el pin. Un
toque posterior en otro punto SHALL reposicionar el pin, sin dejar el
anterior. La latitud resultante SHALL quedar acotada al rango que la
proyección puede representar y la longitud SHALL normalizarse al rango
`[-180, 180]`.

#### Scenario: Proyectar y volver a proyectar devuelve el mismo punto

- **WHEN** se proyecta una coordenada conocida a un punto de pantalla y ese
  punto se convierte de nuevo a coordenadas
- **THEN** se recupera la coordenada de partida

#### Scenario: Un segundo toque mueve el pin

- **WHEN** hay un pin colocado y el jugador toca otro punto del mapa
- **THEN** el pin pasa a estar en las coordenadas del nuevo punto y no
  queda ningún pin en la posición anterior

#### Scenario: Arrastrar no coloca pin

- **WHEN** el jugador arrastra el mapa para desplazarlo y levanta el dedo
- **THEN** el mapa se ha desplazado y no se ha colocado ningún pin

#### Scenario: Longitud más allá del meridiano 180

- **WHEN** la inversa de la proyección devuelve una longitud fuera de
  `[-180, 180]`
- **THEN** la longitud del pin se normaliza a ese rango antes de usarse

### Requirement: Encuadre inicial y límites de zoom

El mapa SHALL arrancar con el mundo cubriendo por completo el área visible.
El tope de alejar SHALL ser esa misma escala: el jugador SHALL no poder
reducir el zoom hasta un punto en el que quede a la vista algo que no sea
mundo. El jugador SHALL poder acercar hasta 40 veces esa escala. Cualquier
intento de salirse de ese rango SHALL quedar recortado a sus extremos.

Alejar deja de servir para ver el planeta entero de un vistazo, porque
enseñar el mundo completo obliga a dejar franjas vacías por encima y por
debajo en una pantalla vertical, y esas franjas se leen como un mapa roto.
El encuadre de partida y el tope de alejar pasan por tanto a ser el mismo
valor.

#### Scenario: Encuadre al abrir el mapa

- **WHEN** se muestra la fase de mapa por primera vez
- **THEN** el mundo aparece cubriendo todo el área visible, sin ninguna
  franja de fondo a la vista, y centrado

#### Scenario: Alejar hasta el límite

- **WHEN** el jugador aleja repetidamente
- **THEN** el zoom se detiene en la escala a la que el mundo cubre el área
  visible, sin que llegue a verse fondo por ningún borde

#### Scenario: Acercar hasta el límite

- **WHEN** el jugador acerca repetidamente
- **THEN** el zoom se detiene en 40 veces la escala inicial

#### Scenario: El área visible cambia de tamaño

- **WHEN** el área visible cambia de alto o de ancho con el mapa ya montado
- **THEN** el mundo sigue cubriéndola por completo y el zoom se recorta a los
  límites nuevos, conservando el centro que se estaba mirando

### Requirement: El desplazamiento no deja salir del mundo

El mapa SHALL impedir que el desplazamiento saque el mundo del área visible:
en cada eje, el desplazamiento SHALL recortarse de forma que el borde del
mundo nunca entre en el área visible. Como el mundo cubre siempre el área
visible, no existe ninguna escala a la que quede hueco vacío a un lado. El
mundo SHALL no repetirse ni continuar al pasar el meridiano 180.

#### Scenario: Arrastrar más allá del borde

- **WHEN** el jugador arrastra el mapa más allá del borde del mundo
- **THEN** el desplazamiento se detiene con el borde del mundo pegado al
  borde del área visible, sin dejar hueco vacío a ese lado

#### Scenario: El mundo cubre el área visible a cualquier zoom

- **WHEN** el jugador aleja hasta el tope y arrastra en cualquier dirección
- **THEN** el área visible sigue enteramente ocupada por mundo, en los dos
  ejes

#### Scenario: Desplazamiento en el eje que ya está justo

- **WHEN** en un eje el mundo mide exactamente lo que el área visible
- **THEN** en ese eje el mundo queda pegado a los dos bordes y no se puede
  desplazar, mientras el otro eje sigue admitiendo arrastre

### Requirement: Controles de zoom accesibles con el pulgar

El mapa SHALL ofrecer botones de acercar y alejar además del gesto de
pellizco, y pulsarlos SHALL cambiar el zoom manteniendo fijo el centro del
área visible.

#### Scenario: Pulsar el botón de acercar

- **WHEN** el jugador pulsa el botón de acercar
- **THEN** el mapa se acerca alrededor del centro del área visible

#### Scenario: Pulsar un botón de zoom no coloca pin

- **WHEN** el jugador pulsa el botón de acercar o el de alejar
- **THEN** el zoom cambia y no se coloca ningún pin

### Requirement: El mapa muestra la ubicación real junto al pin del jugador

El mapa SHALL poder mostrar, además del pin del jugador, un segundo pin en
la ubicación real de un desafío, distinguible del primero a simple vista
(color propio y rótulo), y SHALL poder trazar entre los dos una línea
punteada que siga la ruta más corta sobre la esfera.

La línea SHALL poder dibujarse de forma progresiva, desde el pin del
jugador hasta el pin real, y SHALL seguir apuntando a los dos pines cuando
la cámara cambia de encuadre.

#### Scenario: Los dos pines se distinguen

- **WHEN** el mapa muestra el pin del jugador y el de la ubicación real
- **THEN** cada uno se dibuja en su punto de pantalla con su propio color y
  rótulo, sin taparse mutuamente

#### Scenario: La línea recorre el camino más corto sobre la esfera

- **WHEN** se traza la línea entre dos coordenadas separadas en longitud
- **THEN** la línea sigue el arco del gran círculo entre ellas, no la recta
  de la proyección

#### Scenario: La línea se dibuja progresivamente

- **WHEN** el progreso de la línea es del 40 %
- **THEN** solo está dibujado el primer 40 % del recorrido, empezando en el
  pin del jugador

#### Scenario: La línea sigue a la cámara

- **WHEN** la cámara cambia de escala o desplazamiento mientras la línea
  está dibujada
- **THEN** la línea se redibuja pegada a los dos pines en su posición nueva

### Requirement: Encuadre automático de varias coordenadas con márgenes

El mapa SHALL poder calcular el encuadre —escala y desplazamiento— que deja
un conjunto de coordenadas visible dentro del área útil, respetando los
márgenes que se le indiquen por cada lado, y SHALL poder adoptar un
encuadre calculado sin pasar por los gestos del jugador, para poder animar
la transición desde el encuadre actual.

El encuadre calculado SHALL usar la mayor escala a la que las coordenadas
quepan dentro del área útil, de modo que el resultado sea siempre el
acercamiento máximo posible y no un encuadre más lejano que también las
contuviera.

El encuadre calculado SHALL priorizar que todas las coordenadas queden
visibles por encima de mantener el mundo cubriendo el área visible. Mientras
quepan, el encuadre SHALL no alejar por debajo del encuadre de partida del
mapa. Cuando no quepan —dos coordenadas separadas en longitud más de lo que
ese encuadre abarca—, el encuadre SHALL poder alejar hasta la escala a la que
el mundo entero cabe en pantalla, aunque eso deje franjas de fondo a la
vista.

Ese suelo más bajo SHALL ser alcanzable únicamente adoptando un encuadre
calculado, nunca mediante un gesto del jugador, y SHALL deshacerse al volver
al encuadre de partida.

#### Scenario: Dos coordenadas quedan dentro del área útil

- **WHEN** se encuadran dos coordenadas indicando un margen superior y otro
  inferior distintos
- **THEN** las dos caen dentro del área que queda al descontar esos
  márgenes

#### Scenario: Coordenadas próximas se separan en pantalla

- **WHEN** se encuadran dos coordenadas separadas por unos pocos kilómetros
- **THEN** la escala resultante es la máxima permitida y las dos coordenadas
  caen en puntos de pantalla distintos, no superpuestas

#### Scenario: Coordenadas muy próximas no rebasan el zoom máximo

- **WHEN** se encuadran dos coordenadas separadas por unos pocos metros
- **THEN** la escala resultante se queda en el zoom máximo permitido, en
  vez de dispararse

#### Scenario: Coordenadas que caben sin alejar

- **WHEN** se encuadran dos coordenadas cuya separación cabe dentro de lo que
  abarca el encuadre de partida
- **THEN** la escala resultante es igual o mayor que la de ese encuadre,
  nunca menor, y el mundo sigue cubriendo el área visible

#### Scenario: Coordenadas en extremos opuestos del mundo

- **WHEN** se encuadran dos coordenadas separadas en longitud más de lo que
  abarca el encuadre de partida
- **THEN** la escala baja lo justo para que las dos queden dentro del área
  útil, sin pasar de la escala a la que el mundo entero cabe en pantalla, y
  el mundo queda centrado en el eje en el que no llena

#### Scenario: El suelo bajo no se alcanza con los dedos

- **WHEN** el jugador aleja repetidamente con el gesto o con el botón
- **THEN** el zoom se detiene en la escala a la que el mundo cubre el área
  visible, sin llegar a la escala que sí puede alcanzar un encuadre calculado

### Requirement: El mapa puede quedar en modo no interactivo

El mapa SHALL poder mostrarse en un modo que no acepte gestos ni ofrezca
los controles de zoom, para las fases en las que la jugada ya está cerrada
y el encuadre lo decide la pantalla.

#### Scenario: Gestos ignorados en modo no interactivo

- **WHEN** el mapa está en modo no interactivo y el jugador lo toca,
  arrastra o pellizca
- **THEN** ni el pin ni el encuadre cambian

#### Scenario: Sin controles de zoom en modo no interactivo

- **WHEN** el mapa está en modo no interactivo
- **THEN** no se muestran los botones de acercar y alejar

### Requirement: El dibujo del mundo llega hasta el borde de la proyección

La geometría del mundo SHALL cubrir el cuadrado de la proyección hasta sus
cuatro bordes, sin dejar en ninguno de ellos una banda sin rellenar entre la
tierra más extrema y el canto del mundo.

Mercator cierra el mundo en un cuadrado a ±85,051° y no puede representar nada
más allá; una masa de tierra que en el dato llegue más al sur SHALL verse como
hielo continuo hasta el canto inferior, y no como un relleno que se interrumpe
a media pantalla. Un relleno interrumpido se lee exactamente igual que un mapa
recortado.

La comprobación SHALL hacerse sobre el asset commiteado, no sobre la pantalla:
es el dato el que garantiza el invariante, y así una regeneración futura no
puede reintroducir el corte sin que salte un test.

#### Scenario: La tierra más austral alcanza el canto inferior

- **WHEN** se proyecta la geometría empaquetada al cuadrado de la proyección y
  se mide el relleno a la altura del canto inferior
- **THEN** el relleno de tierra ocupa prácticamente todo el ancho del mundo,
  sin ninguna banda de océano entre la tierra más austral y el canto

#### Scenario: Ningún anillo se cierra justo por encima del canto

- **WHEN** se recorren los anillos de tierra que descienden hasta la zona
  polar
- **THEN** ninguno se cierra por el sur a una latitud que caiga dentro del
  mundo representable dejando un canto de relleno a la vista

### Requirement: La geometría no trae anillos degenerados

La geometría del mundo SHALL no contener anillos que al proyectarse encierren
área cero.

Un anillo colapsado en una línea no aporta nada al relleno, pero sí se traza
en la pasada de contorno: dibuja un trazo que no corresponde a ninguna
frontera real.

#### Scenario: Ningún anillo encierra área cero

- **WHEN** se recorren todos los anillos de la geometría empaquetada y se
  calcula el área que encierra cada uno
- **THEN** ninguna es cero

### Requirement: Los cruces del antimeridiano no se dibujan como trazos

La geometría del mundo SHALL no contener ningún segmento que recorra más de
media vuelta de longitud.

Un anillo que pasa del meridiano 180 al -180 salta en la proyección de un
borde al otro del cuadrado. Ese salto se traza en la pasada de contorno y
dibuja una raya que cruza el mapa entero de lado a lado, atravesando océanos y
continentes por los que no pasa ninguna frontera. Un anillo que cruce el
antimeridiano SHALL partirse en el cruce, y cada trozo SHALL cerrarse por su
lado del antimeridiano.

#### Scenario: Ningún segmento cruza el mapa de lado a lado

- **WHEN** se recorren los segmentos de todos los anillos de la geometría
  empaquetada
- **THEN** ninguno separa sus dos extremos más de 180° de longitud

#### Scenario: Un país a los dos lados del antimeridiano sigue completo

- **WHEN** se dibuja un país cuyo territorio queda a ambos lados del meridiano
  180
- **THEN** cada parte aparece pegada a su borde del mapa, con su forma propia,
  y no hay ningún trazo uniéndolas por encima del océano

### Requirement: La geometría no repite puntos dentro de un anillo

Ningún anillo de la geometría del mundo SHALL contener dos puntos iguales
seguidos dentro de su recorrido.

Un punto repetido deja un segmento de longitud cero. El relleno par-impar lo
ignora y en pantalla no se nota, que es justo lo que lo hace peligroso: es un
defecto que ningún test de relleno puede ver, y señala que el tratamiento de
la geometría está cortando o empalmando por un vértice que el dato ya traía
duplicado.

El punto de cierre explícito de un anillo —el último, que repite al primero—
no cuenta: es la convención con la que viene el dato y no deja ningún segmento
dentro del recorrido.

#### Scenario: Ningún anillo repite un punto seguido

- **WHEN** se recorren en orden los puntos de cada anillo de la geometría
  empaquetada
- **THEN** ningún punto es igual al inmediatamente anterior

### Requirement: El umbral que descarta anillos degenerados conserva margen

El área del anillo legítimo más pequeño de la geometría SHALL quedar muy por
encima del umbral con el que el generador descarta los anillos degenerados.

El generador tira los anillos que encierran menos de una cierta área porque no
son territorio sino artefactos del formato. Ese filtro solo es seguro mientras
ninguna isla de verdad ande cerca del umbral; si un dataset futuro trajera una,
desaparecería del mapa sin que nadie se enterase.

#### Scenario: La isla más pequeña está lejos del umbral

- **WHEN** se calcula el área de todos los anillos de la geometría empaquetada
  y se toma la menor
- **THEN** es varios órdenes de magnitud mayor que el umbral con el que se
  descartan los anillos degenerados

### Requirement: El asset conserva la cobertura del mundo al regenerarse

La geometría empaquetada SHALL seguir cubriendo todos los países y todas las
masas de tierra del dataset de partida después de cualquier tratamiento que se
le aplique en el generador.

Los arreglos del generador fusionan, acotan y parten anillos; ninguno puede
acabar perdiendo territorio, porque el juego consiste en reconocer la forma de
la costa y una isla que desaparece es un desafío que deja de tener respuesta.

#### Scenario: No se pierde ningún país

- **WHEN** se carga el asset regenerado
- **THEN** trae el mismo número de países que el dataset de partida y cada uno
  conserva al menos un anillo con área

#### Scenario: Las coordenadas siguen siendo válidas

- **WHEN** se recorren todos los puntos de la geometría regenerada
- **THEN** todas las latitudes caen en `[-90, 90]` y todas las longitudes en
  `[-180, 180]`

