## ADDED Requirements

### Requirement: La cabecera del camino no corta el apodo ni el progreso
La barra superior de la Home SHALL mostrar el apodo del jugador y su línea de progreso completos, reduciendo su tamaño si no caben en el ancho disponible en vez de cortarlos con puntos suspensivos. La línea de progreso SHALL usar el formato compacto «Nivel N/M · E/T ★».

#### Scenario: Apodo largo con muchos puntos
- **WHEN** un jugador con un apodo de 16 caracteres y más de 100 000 puntos abre la Home en un móvil de 390 px de ancho
- **THEN** su apodo y la línea «Nivel N/M · E/T ★» se leen completos, sin puntos suspensivos

### Requirement: El botón de clasificación tiene nombre accesible
El botón con el icono de trofeo de la barra superior SHALL anunciarse al lector de pantalla como un botón llamado «Clasificación».

#### Scenario: Lector de pantalla sobre el trofeo
- **WHEN** el lector de pantalla recorre la barra superior de la Home
- **THEN** anuncia el trofeo como el botón «Clasificación»
