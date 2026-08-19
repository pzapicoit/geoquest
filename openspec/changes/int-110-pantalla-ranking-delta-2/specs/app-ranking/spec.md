## MODIFIED Requirements

### Requirement: Pantalla única con tres pestañas de clasificación
El sistema SHALL mostrar una pantalla "Clasificación" con tres pestañas navegables — Global, Camino y Temática — donde cambiar de pestaña recarga la clasificación correspondiente sin salir de la pantalla.

#### Scenario: El jugador cambia de pestaña
- **WHEN** el jugador pulsa la pestaña "Temática" estando en "Global"
- **THEN** la pantalla carga y muestra `clasificacion_por_tematica` para la temática seleccionada, sin navegar a otra pantalla

#### Scenario: Cabecera contextual por pestaña
- **WHEN** la pestaña activa es Global, o Camino/Temática con una tarjeta abierta
- **THEN** el subtítulo de la cabecera refleja esa selección (p. ej. "Global · acumulado histórico", "Nivel N · <temática de esa parada>", "<Temática> · ranking") y la cabecera muestra siempre los puntos totales del propio jugador

### Requirement: Rejilla de tarjetas para elegir parada o temática, con clasificación de dos niveles
El sistema SHALL mostrar, solo en las pestañas Camino y Temática, una rejilla de tarjetas (una por parada del camino o por temática) en vez de la clasificación directamente; la pestaña Global no muestra rejilla, va directa a la clasificación. Tocar una tarjeta SHALL mostrar la clasificación de esa parada/temática (podio, lista y fila propia), sustituyendo la rejilla dentro de la misma pantalla.

El botón de volver de la cabecera SHALL ser contextual: si hay una tarjeta abierta (clasificación visible en Camino o Temática), SHALL volver a la rejilla de esa pestaña sin salir de la pantalla; en cualquier otro caso (rejilla sin tarjeta abierta, o pestaña Global) SHALL salir de la pantalla de Clasificación.

Cada tarjeta SHALL mostrar un adelanto de la posición del propio jugador en esa parada/temática concreta ("Tú #N" si tiene una posición, o "Sin jugar" si no tiene puntuación agregable todavía), resuelto contra las mismas funciones de clasificación que la vista completa. Las tarjetas de Temática SHALL mostrar la imagen real de portada de esa temática cuando esté disponible. El sistema NO SHALL mostrar un contador de jugadores totales ni de preguntas por tarjeta, por no estar disponibles en las funciones de clasificación actuales.

#### Scenario: Rejilla visible en Camino
- **WHEN** la pestaña activa es "Camino" y no hay ninguna tarjeta abierta
- **THEN** se muestra una rejilla con una tarjeta por parada del camino disponible, etiquetada "Nivel N"

#### Scenario: Rejilla visible en Temática
- **WHEN** la pestaña activa es "Temática" y no hay ninguna tarjeta abierta
- **THEN** se muestra una rejilla con una tarjeta por temática disponible, con su imagen de portada cuando exista

#### Scenario: Rejilla ausente en Global
- **WHEN** la pestaña activa es "Global"
- **THEN** no se muestra ninguna rejilla; se ve la clasificación global directamente

#### Scenario: Tocar una tarjeta abre su clasificación
- **WHEN** el jugador toca una tarjeta de la rejilla (de Camino o de Temática)
- **THEN** la pantalla muestra la clasificación de esa parada/temática (podio, lista, fila propia) en vez de la rejilla

#### Scenario: Volver desde una clasificación abierta vuelve a la rejilla
- **WHEN** el jugador pulsa el botón ‹ de la cabecera teniendo una tarjeta abierta en Camino o Temática
- **THEN** la pantalla vuelve a mostrar la rejilla de esa pestaña, sin salir de la pantalla de Clasificación

#### Scenario: Volver sin tarjeta abierta sale de la pantalla
- **WHEN** el jugador pulsa el botón ‹ de la cabecera estando en la rejilla (sin tarjeta abierta) o en la pestaña Global
- **THEN** la pantalla de Clasificación se cierra, volviendo a la pantalla anterior

#### Scenario: Adelanto de posición en una tarjeta con puntuación
- **WHEN** el propio jugador tiene una posición real en la parada/temática de una tarjeta
- **THEN** la tarjeta muestra "Tú #N" con esa posición

#### Scenario: Adelanto de posición en una tarjeta sin jugar
- **WHEN** el propio jugador no tiene puntuación agregable todavía en la parada/temática de una tarjeta (`posicion = null`)
- **THEN** la tarjeta muestra "Sin jugar" en vez de un número de puesto

#### Scenario: Cambiar de pestaña vuelve siempre a la rejilla
- **WHEN** el jugador cambia de pestaña teniendo una tarjeta abierta en Camino o Temática
- **THEN** al volver a esa pestaña se muestra de nuevo la rejilla, no la clasificación que estaba abierta
