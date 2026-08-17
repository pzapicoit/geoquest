## MODIFIED Requirements

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

## ADDED Requirements

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

El encuadre calculado SHALL respetar los mismos límites de zoom y de
desplazamiento que cualquier otro movimiento de cámara.

#### Scenario: Dos coordenadas quedan dentro del área útil

- **WHEN** se encuadran dos coordenadas indicando un margen superior y otro
  inferior distintos
- **THEN** las dos caen dentro del área que queda al descontar esos
  márgenes

#### Scenario: Coordenadas muy próximas no rebasan el zoom máximo

- **WHEN** se encuadran dos coordenadas separadas por unos pocos metros
- **THEN** la escala resultante se queda en el zoom máximo permitido, en
  vez de dispararse

#### Scenario: Coordenadas en extremos opuestos del mundo

- **WHEN** se encuadran dos coordenadas en extremos opuestos del mundo
- **THEN** la escala resultante no baja de la mínima permitida y el
  desplazamiento sigue sin dejar hueco fuera del mundo

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
