## ADDED Requirements

### Requirement: El dibujo del mundo llega hasta el borde de la proyección

La geometría del mundo SHALL cubrir el cuadrado de la proyección hasta sus
cuatro bordes, sin dejar en ninguno de ellos una banda sin rellenar entre la
tierra más extrema y el canto del mundo.

Mercator cierra el mundo en un cuadrado a ±85,051° y no puede representar nada
más allá; una masa de tierra que en el dato llegue más al sur SHALL verse como
hielo continuo hasta el canto inferior, y no como un relleno que se interrumpe
a media pantalla. Un relleno interrumpido se lee exactamente igual que un mapa
recortado, que es el defecto que este cambio corrige.

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
frontera real. En el caso del cierre polar de la Antártida eso era una raya a
todo lo ancho pegada al canto inferior del mapa.

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
no cuenta: es la convención con la que viene el dato y no deja ningún
segmento dentro del recorrido.

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
