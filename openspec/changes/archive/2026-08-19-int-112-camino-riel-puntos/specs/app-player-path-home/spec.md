## ADDED Requirements

### Requirement: Indicador de puntos totales junto a cada parada
El indicador de la columna izquierda de cada parada SHALL mostrar los
puntos totales acumulados del jugador (el mismo valor que se muestra en
la barra superior), formateados con separador de miles, en vez del
número de estrellas requeridas para esa parada.

#### Scenario: Se muestran los puntos totales en cada parada
- **WHEN** la Home renderiza el camino de un jugador con puntos totales
  acumulados
- **THEN** el indicador izquierdo de cada parada muestra ese mismo
  valor de puntos totales, formateado con separador de miles

#### Scenario: Todas las paradas muestran el mismo valor
- **WHEN** la Home renderiza un camino con varias paradas
- **THEN** el indicador izquierdo de todas ellas muestra idéntico valor
  de puntos totales, sin variar de una parada a otra

#### Scenario: Jugador sin puntos todavía
- **WHEN** un jugador sin respuestas registradas (puntos totales = 0)
  abre la Home
- **THEN** el indicador izquierdo de cada parada muestra 0

### Requirement: Candado visible en parada bloqueada
Toda parada cuya posición traiga `desbloqueado = false` SHALL mostrar
un icono de candado sobre su tarjeta, además del tratamiento atenuado
ya exigido para ese estado por "Estado visual de parada bloqueada y no
interactiva".

#### Scenario: Parada bloqueada muestra candado
- **WHEN** la Home renderiza una parada cuya posición trae
  `desbloqueado = false`
- **THEN** esa parada muestra un icono de candado visible sobre su
  tarjeta

#### Scenario: Parada desbloqueada no muestra candado
- **WHEN** la Home renderiza una parada cuya posición trae
  `desbloqueado = true`
- **THEN** esa parada no muestra ningún icono de candado
