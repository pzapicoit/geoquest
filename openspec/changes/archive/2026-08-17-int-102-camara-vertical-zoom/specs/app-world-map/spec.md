## MODIFIED Requirements

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
