## ADDED Requirements

### Requirement: La línea del siguiente nivel no repite el nombre
En la bienvenida de regreso, la línea del siguiente nivel SHALL mostrar «Siguiente: <nombre de la parada> · <temática>» cuando la parada tiene título propio distinto del de su temática, y solo «Siguiente: <temática>» en otro caso, sin repetir el mismo nombre dos veces.

#### Scenario: Parada sin título propio
- **WHEN** la siguiente parada bloqueada no tiene título propio y su temática es «Películas»
- **THEN** la bienvenida muestra «Siguiente: Películas»

#### Scenario: Parada con título propio
- **WHEN** la siguiente parada se titula «Banderas del Mundo 01» y su temática es «Banderas»
- **THEN** la bienvenida muestra «Siguiente: Banderas del Mundo 01 · Banderas»
