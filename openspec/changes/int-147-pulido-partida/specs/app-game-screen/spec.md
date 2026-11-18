## ADDED Requirements

### Requirement: La cabecera de la partida da su propia línea al nombre de la parada
La tarjeta de progreso de la cabecera de la partida SHALL mostrar «Desafío N de M» en una línea y, cuando la parada tiene nombre, ese nombre en una línea propia debajo, de modo que ninguno de los dos se corte por compartir el ancho con el otro.

#### Scenario: Parada con nombre largo
- **WHEN** el jugador juega una parada titulada «Monumentos del Mundo» en un móvil de 390 px de ancho
- **THEN** la cabecera muestra «Desafío 1 de 4» completo y, debajo, «MONUMENTOS DEL MUNDO» completo

### Requirement: La hoja de resultado no enseña cifras antes de contarlas
En la hoja de resultado del revelado, la distancia y los puntos ganados SHALL mostrar «—» hasta que su contador empiece a avanzar, en vez de «0,0 km» o «+0». El desglose de precisión y bonus SHALL aparecer a la vez que cuentan los puntos, no antes.

#### Scenario: Primer fotograma de la hoja
- **WHEN** la hoja de resultado aparece y los contadores todavía no han empezado
- **THEN** la distancia y los puntos muestran «—»
- **AND** el desglose de precisión todavía no se ve

#### Scenario: Contadores terminados
- **WHEN** los contadores de la hoja han terminado
- **THEN** se ven la distancia, los puntos ganados y el desglose con sus valores finales

### Requirement: La pista nombra bien su tipo y no repite la pregunta
La cabecera de la tarjeta de pista SHALL rotular el contenido de tipo imagen como «IMAGEN · PISTA N», no como «FOTO», porque las imágenes del juego son ilustraciones. La instrucción fija bajo una pista de imagen SHALL limitarse a «Coloca tu pin lo más cerca que puedas.», sin repetir la pregunta que ya plantea el objetivo de la temática.

#### Scenario: Pista de imagen
- **WHEN** se muestra la pista de un desafío de tipo imagen
- **THEN** su cabecera dice «IMAGEN · PISTA N» y su instrucción fija es «Coloca tu pin lo más cerca que puedas.»

### Requirement: El botón de cerrar la pista tiene nombre accesible
El botón con la X de la tarjeta de pista SHALL anunciarse al lector de pantalla como un botón llamado «Cerrar pista».

#### Scenario: Lector de pantalla sobre la X de la pista
- **WHEN** el lector de pantalla recorre la tarjeta de pista
- **THEN** anuncia la X como el botón «Cerrar pista»
