## ADDED Requirements

### Requirement: El mapa dibuja el mundo sin ningún topónimo

El mapa de juego SHALL dibujar el mundo a partir de geometría vectorial
empaquetada en la app (fronteras de países, masas de tierra y retícula de
meridianos y paralelos), sin nombres de países, ciudades, mares ni
ningún otro rótulo, y sin depender de un servicio de teselas en red.

Adivinar en GeoQuest consiste en reconocer la forma del terreno: un
rótulo visible convertiría cualquier desafío en una lectura, no en una
deducción.

#### Scenario: El mapa se dibuja sin conexión a la red

- **WHEN** el jugador entra a la fase de mapa sin conexión a internet
- **THEN** el mapa se dibuja igualmente con la geometría empaquetada en la
  app, sin mensajes de error de mapa y sin peticiones a ningún servidor de
  teselas

#### Scenario: El mapa no rotula ningún lugar

- **WHEN** se inspecciona lo que el mapa dibuja a cualquier nivel de zoom
- **THEN** no aparece ningún texto sobre el mapa: solo relleno de tierra,
  contorno de fronteras, océano y retícula

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

El mapa SHALL arrancar con el mundo llenando la altura del área visible.
El jugador SHALL poder alejar hasta que el mundo entero quepa en pantalla
y acercar hasta 14 veces la escala inicial. Cualquier intento de salirse
de ese rango SHALL quedar recortado a sus extremos.

#### Scenario: Encuadre al abrir el mapa

- **WHEN** se muestra la fase de mapa por primera vez
- **THEN** el mundo aparece llenando la altura del área visible y centrado
  horizontalmente

#### Scenario: Alejar hasta ver el mundo entero

- **WHEN** el jugador aleja repetidamente
- **THEN** el zoom se detiene en la escala a la que el mundo completo cabe
  en pantalla, y no sigue reduciéndose

#### Scenario: Acercar hasta el límite

- **WHEN** el jugador acerca repetidamente
- **THEN** el zoom se detiene en 14 veces la escala inicial

### Requirement: El desplazamiento no deja salir del mundo

El mapa SHALL impedir que el desplazamiento saque el mundo del área
visible: en cada eje, si el mundo es más grande que el área visible se
recorta el desplazamiento a sus bordes, y si es más pequeño se mantiene
centrado. El mundo SHALL no repetirse ni continuar al pasar el meridiano
180.

#### Scenario: Arrastrar más allá del borde

- **WHEN** el jugador arrastra el mapa más allá del borde del mundo
- **THEN** el desplazamiento se detiene con el borde del mundo pegado al
  borde del área visible, sin dejar hueco vacío a ese lado

#### Scenario: Mundo más pequeño que el área visible

- **WHEN** el zoom deja el mundo más estrecho o más bajo que el área
  visible
- **THEN** el mundo queda centrado en ese eje y no se puede desplazar en él

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
