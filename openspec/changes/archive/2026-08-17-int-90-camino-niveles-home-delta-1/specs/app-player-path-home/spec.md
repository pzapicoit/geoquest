## ADDED Requirements

### Requirement: Botón fijo para jugar la parada actual
La Home SHALL mostrar un botón fijo sobre el camino, siempre visible,
que navegue a la pantalla de juego de la parada `es_actual` cuando
exista una. Si ninguna posición trae `es_actual = true` (camino
completo), el botón no SHALL mostrarse.

#### Scenario: Hay una parada actual
- **WHEN** una posición del camino trae `es_actual = true`
- **THEN** la Home muestra un botón fijo que, al tocarlo, navega a la
  pantalla de juego del `nivel_id` de esa posición

#### Scenario: Camino completo sin parada actual
- **WHEN** ninguna posición del camino trae `es_actual = true`
- **THEN** la Home no muestra el botón fijo de jugar

### Requirement: Camino corto queda apoyado sobre el botón, no pegado al fondo
Cuando el conjunto de paradas y fronteras no llene el espacio visible
entre la barra superior y el botón fijo de jugar, la Home SHALL
mantenerlo apoyado justo encima del botón (con un margen pequeño y
fijo), dejando el hueco sobrante hacia la barra superior, en vez de
anclarlo al borde inferior de la pantalla o centrarlo repartiendo el
hueco arriba y abajo.

#### Scenario: Camino con una sola parada
- **WHEN** el camino tiene una única posición y su altura es menor que
  el espacio visible entre la barra superior y el botón de jugar
- **THEN** esa parada se muestra apoyada justo encima del botón de
  jugar, no pegada al borde inferior de la pantalla

#### Scenario: Camino largo que ya llena la pantalla
- **WHEN** el conjunto de paradas y fronteras ocupa más espacio que el
  disponible entre la barra superior y el botón de jugar
- **THEN** el camino se comporta igual que antes de este cambio:
  desplazable, sin centrado adicional

### Requirement: Altura de tarjeta de parada según el diseño de referencia
Cada tarjeta de parada SHALL usar la misma altura que la fila del mock
de referencia (`[App] - Camino vertical.dc.html`, `ROW_H = 208`), no
una altura reducida.

#### Scenario: Se renderiza una tarjeta de parada
- **WHEN** la Home renderiza una tarjeta de parada (no una frontera)
- **THEN** su altura es de 208 puntos lógicos, igual que en el diseño
  de referencia
