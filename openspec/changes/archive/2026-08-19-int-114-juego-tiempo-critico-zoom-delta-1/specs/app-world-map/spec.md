## MODIFIED Requirements

### Requirement: Tocar el mapa coloca el pin en coordenadas reales

El mapa SHALL convertir el punto tocado en pantalla a latitud y longitud
reales mediante la inversa de su proyección, y colocar allí el pin. Un
toque posterior en otro punto SHALL reposicionar el pin, sin dejar el
anterior. La latitud resultante SHALL quedar acotada al rango que la
proyección puede representar y la longitud SHALL normalizarse al rango
`[-180, 180]`.

El pin SHALL colocarse en cuanto el dedo se levanta, sin esperar a
descartar que llegue un segundo toque: colocar el pin es la acción
principal de la pantalla de juego y no puede quedar detrás del plazo de
espera del doble toque. La única excepción es el segundo toque de un doble
toque, que no coloca pin y deshace el del primero, según el requisito del
doble toque.

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

#### Scenario: El pin no espera al plazo del doble toque

- **WHEN** el jugador da un solo toque en el mapa y levanta el dedo
- **THEN** el pin ya está colocado en ese punto, sin que haya hecho falta
  esperar ningún plazo

### Requirement: Doble toque acerca el mapa sobre el punto tocado

El mapa interactivo SHALL interpretar dos toques seguidos y cercanos como
la petición de acercar sobre ese punto: SHALL aumentar el zoom por un
factor fijo manteniendo quieta la posición de pantalla del segundo toque, y
SHALL hacerlo con una transición animada breve en vez de un salto. Dos
toques SHALL contar como doble toque solo si el segundo llega dentro del
plazo habitual de doble toque del sistema y a poca distancia del primero;
en cualquier otro caso son dos toques simples independientes.

Un doble toque SHALL acercar sin dejar pin: acercarse a mirar y responder
son dos intenciones distintas. Como el primer toque de la pareja coloca el
pin al instante —y eso no cambia—, al confirmarse el doble toque el mapa
SHALL deshacer ese pin y volver al que hubiera antes del gesto, de forma
que un pin ya colocado sobreviva al doble toque y el mapa sin pin siga sin
pin.

El acercamiento SHALL respetar los límites de zoom y el recorte de
desplazamiento del mapa, igual que el pellizco y los botones. El mapa no
interactivo SHALL ignorar el doble toque, como ignora el resto de gestos.
Un gesto nuevo del jugador —pellizco o arrastre— SHALL interrumpir la
animación en curso, que nunca SHALL quedar peleando con el encuadre de un
revelado.

#### Scenario: Doble toque sobre un punto del mapa

- **WHEN** el jugador da dos toques seguidos y cercanos sobre un punto del
  mapa
- **THEN** el mapa acaba más acercado y la coordenada que estaba bajo ese
  punto sigue estando bajo ese mismo punto de pantalla

#### Scenario: Un doble toque no deja pin

- **WHEN** el jugador da un doble toque sobre un mapa sin ningún pin
- **THEN** el mapa se acerca y sigue sin ningún pin

#### Scenario: Un doble toque no se lleva el pin que ya había

- **WHEN** el jugador tiene el pin colocado en un punto y da un doble toque
  en otro punto del mapa
- **THEN** el mapa se acerca sobre el punto del doble toque y el pin sigue
  donde estaba

#### Scenario: El acercamiento es animado

- **WHEN** acaba de completarse un doble toque
- **THEN** la escala del mapa recorre valores intermedios en fotogramas
  sucesivos, en vez de pasar de la inicial a la final en uno solo

#### Scenario: Dos toques lejanos no son un doble toque

- **WHEN** el jugador da dos toques seguidos en puntos alejados de la
  pantalla
- **THEN** el mapa no se acerca y el pin acaba en el segundo de los dos
  puntos

#### Scenario: Dos toques separados en el tiempo no son un doble toque

- **WHEN** el jugador da dos toques en el mismo punto separados por más que
  el plazo de doble toque
- **THEN** el mapa no se acerca y queda pin en el segundo de los dos puntos

#### Scenario: Doble toque en el zoom máximo

- **WHEN** el jugador hace un doble toque con el mapa ya en su escala
  máxima
- **THEN** la escala no pasa de la máxima y el mapa se queda donde estaba

#### Scenario: Doble toque cerca del borde del mundo

- **WHEN** el jugador hace un doble toque sobre un punto muy cerca del
  canto del mundo
- **THEN** el mapa se acerca sin dejar hueco entre el mundo y el borde del
  área visible

#### Scenario: El mapa no interactivo ignora el doble toque

- **WHEN** el mapa está en modo no interactivo y recibe dos toques seguidos
- **THEN** ni se acerca ni coloca pin

#### Scenario: Un gesto nuevo corta la animación del doble toque

- **WHEN** el jugador empieza un pellizco o un arrastre mientras corre la
  animación de un doble toque
- **THEN** la animación se detiene y el encuadre lo manda el dedo

#### Scenario: El mapa deja de ser interactivo a media animación

- **WHEN** la jugada se cierra —el mapa pasa a no interactivo— mientras corre
  la animación de un doble toque
- **THEN** la animación se detiene, y el encuadre queda libre para quien lo
  lleve a partir de ese momento
