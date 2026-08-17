## MODIFIED Requirements

### Requirement: El mapa dibuja el mundo sin ningún topónimo

El mapa de juego SHALL dibujar el mundo a partir de geometría vectorial
empaquetada en la app (fronteras de países, masas de tierra y retícula de
meridianos y paralelos), sin nombres de países, ciudades, mares ni
ningún otro rótulo, y sin depender de un servicio de teselas en red.

Adivinar en GeoQuest consiste en reconocer la forma del terreno: un
rótulo visible convertiría cualquier desafío en una lectura, no en una
deducción. Esa restricción rige mientras el jugador todavía está
adivinando: antes de revelar la respuesta, el mapa SHALL no mostrar ningún
topónimo, y el único texto sobre el mapa SHALL ser el rótulo "Tu pin".

Una vez revelada la respuesta, el rótulo del pin de la ubicación real SHALL
poder mostrar el nombre de ese lugar: el desafío ya está resuelto y el
nombre pasa a ser parte del resultado, no una pista. Ningún otro elemento
del mapa —geometría, retícula ni el rótulo del pin del jugador— SHALL
nombrar un lugar en ningún momento.

#### Scenario: El mapa se dibuja sin conexión a la red

- **WHEN** el jugador entra a la fase de mapa sin conexión a internet
- **THEN** el mapa se dibuja igualmente con la geometría empaquetada en la
  app, sin mensajes de error de mapa y sin peticiones a ningún servidor de
  teselas

#### Scenario: El mapa no rotula ningún lugar antes de revelar

- **WHEN** se inspecciona lo que el mapa dibuja a cualquier nivel de zoom,
  antes de que se revele la ubicación real
- **THEN** no aparece ningún texto que nombre un lugar: solo relleno de
  tierra, contorno de fronteras, océano, retícula y, si hay pin del
  jugador, su rótulo "Tu pin"

#### Scenario: El pin real nombra el lugar solo tras revelar

- **WHEN** se revela la ubicación real con un nombre de lugar
- **THEN** el rótulo del pin real muestra ese nombre, y el resto del mapa
  sigue sin ningún otro topónimo

### Requirement: El mapa muestra la ubicación real junto al pin del jugador

El mapa SHALL poder mostrar, además del pin del jugador, un segundo pin en
la ubicación real de un desafío, distinguible del primero a simple vista
(color propio y rótulo), y SHALL poder trazar entre los dos una línea
punteada que siga la ruta más corta sobre la esfera.

El rótulo del pin de la ubicación real SHALL mostrar el nombre del lugar
revelado, no un texto fijo genérico. El rótulo del pin del jugador SHALL
seguir siendo "Tu pin".

Cada rótulo SHALL dibujarse sobre un fondo propio que lo haga legible sobre
cualquier parte del mapa, en una caja independiente del tamaño fijo del pin,
y un nombre que no quepa SHALL truncarse con puntos suspensivos en vez de
desbordar esa caja o romper el layout del pin.

Cuando los dos pines están visibles, sus rótulos SHALL dibujarse en lados
opuestos del pin al que pertenecen —el del pin del jugador por debajo, el
de la ubicación real por encima— de modo que nunca se solapen entre sí,
sin importar cuánto se acerquen los dos pines en pantalla.

La línea SHALL poder dibujarse de forma progresiva, desde el pin del
jugador hasta el pin real, y SHALL seguir apuntando a los dos pines cuando
la cámara cambia de encuadre.

#### Scenario: Los dos pines se distinguen

- **WHEN** el mapa muestra el pin del jugador y el de la ubicación real
- **THEN** cada uno se dibuja en su punto de pantalla con su propio color y
  rótulo, sin taparse mutuamente

#### Scenario: El rótulo del pin real muestra el nombre del lugar

- **WHEN** se revela la ubicación real con un nombre de lugar dado
- **THEN** el rótulo del pin real muestra ese nombre, no la palabra "Real"

#### Scenario: Un nombre de lugar largo no rompe el layout

- **WHEN** el nombre del lugar revelado es más largo de lo que cabe en la
  caja del rótulo
- **THEN** el rótulo se trunca con puntos suspensivos y no se sale de su
  caja ni desplaza al pin

#### Scenario: Los rótulos de los dos pines no se solapan al caer cerca

- **WHEN** el pin del jugador y el pin real caen a pocos píxeles el uno del
  otro en pantalla
- **THEN** el rótulo del pin del jugador aparece por debajo de su pin y el
  del pin real por encima del suyo, sin superponerse

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
