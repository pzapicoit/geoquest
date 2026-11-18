## ADDED Requirements

### Requirement: La cabecera del camino no corta el apodo ni el progreso sin necesidad
La barra superior de la Home SHALL mostrar el apodo del jugador y su línea de progreso reduciendo su tamaño si no caben en el ancho disponible, sin bajar de 13,5 px el apodo ni de 9 px el progreso, y SHALL cortarlos con puntos suspensivos solo si ni a ese tamaño caben. La línea de progreso SHALL usar el formato compacto «Nivel N/M · E/T ★». La fila SHALL no desbordar la pantalla con ningún número de puntos.

#### Scenario: Apodo habitual con puntos de cuatro cifras
- **WHEN** un jugador con el apodo «RutaSalvaje» y 3 727 puntos abre la Home en un móvil de 390 px de ancho
- **THEN** su apodo se lee completo, sin puntos suspensivos

#### Scenario: Apodo largo con muchos puntos
- **WHEN** un jugador con un apodo de 16 caracteres y 123 456 puntos abre la Home en un móvil de 390 px de ancho
- **THEN** el apodo no se pinta por debajo de 13,5 px ni el progreso por debajo de 9 px; si aun así no caben se cortan con puntos suspensivos, y la fila no desborda

### Requirement: El botón de clasificación tiene nombre accesible
El botón con el icono de trofeo de la barra superior SHALL anunciarse al lector de pantalla como un botón llamado «Clasificación».

#### Scenario: Lector de pantalla sobre el trofeo
- **WHEN** el lector de pantalla recorre la barra superior de la Home
- **THEN** anuncia el trofeo como el botón «Clasificación»
