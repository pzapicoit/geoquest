## ADDED Requirements

### Requirement: Pill de comodines en la cabecera del camino

La cabecera de la pantalla Home (camino vertical) SHALL mostrar un indicador con el recuento total de comodines del jugador (suma de los 4 tipos), que al tocarse navega a la pantalla de Comodines.

#### Scenario: Se muestra el recuento total

- **WHEN** el jugador entra en la Home
- **THEN** la cabecera muestra la suma de unidades de los 4 tipos de comodín

#### Scenario: Se navega a la pantalla de Comodines

- **WHEN** el jugador toca el indicador de comodines en la cabecera
- **THEN** se abre la pantalla de Comodines
