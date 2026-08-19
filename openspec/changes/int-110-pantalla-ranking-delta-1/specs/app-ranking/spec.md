## MODIFIED Requirements

### Requirement: Pantalla única con tres pestañas de clasificación
El sistema SHALL mostrar una pantalla "Clasificación" con tres pestañas navegables — Global, Camino y Temática — donde cambiar de pestaña recarga la clasificación correspondiente sin salir de la pantalla.

#### Scenario: El jugador cambia de pestaña
- **WHEN** el jugador pulsa la pestaña "Temática" estando en "Global"
- **THEN** la pantalla carga y muestra `clasificacion_por_tematica` para la temática seleccionada, sin navegar a otra pantalla

#### Scenario: Cabecera contextual por pestaña
- **WHEN** la pestaña activa es Global, Camino o Temática
- **THEN** el subtítulo de la cabecera refleja esa pestaña (p. ej. "Global · acumulado histórico", "Camino N · <temática de esa parada>", "<Temática> · ranking") y la cabecera muestra siempre los puntos totales del propio jugador

### Requirement: Selector de parada o temática en las pestañas Camino y Temática
El sistema SHALL mostrar, solo en las pestañas Camino y Temática, un selector de chips horizontales para elegir la parada del camino o la temática concreta a consultar; la pestaña Global no muestra este selector. El texto de cada chip SHALL mostrarse completo, sin recortarse contra el borde del chip.

#### Scenario: Selector visible en Camino
- **WHEN** la pestaña activa es "Camino"
- **THEN** se muestran chips con cada parada del camino disponible (etiquetados "Camino N"), y seleccionar uno recarga `clasificacion_por_camino` para esa parada

#### Scenario: Selector visible en Temática
- **WHEN** la pestaña activa es "Temática"
- **THEN** se muestran chips con cada temática disponible, y seleccionar uno recarga `clasificacion_por_tematica` para esa temática

#### Scenario: Selector ausente en Global
- **WHEN** la pestaña activa es "Global"
- **THEN** no se muestra el selector de chips

### Requirement: Lista scrollable del resto de posiciones
El sistema SHALL mostrar en una lista scrollable las posiciones no incluidas en el podio, cada una con puesto, avatar, nombre, dato contextual soportado por el backend y puntuación.

El dato contextual SHALL ser, según la pestaña: número de niveles superados en la pestaña Global; si esa parada está superada (`superado`) en la pestaña Camino; número de niveles superados de esa temática en la pestaña Temática. El sistema NO SHALL mostrar datos de racha, número de intentos ni porcentaje de acierto de otros jugadores, ni ningún indicador de variación (▲/▼), por no estar disponibles en las funciones de clasificación actuales.

#### Scenario: Fila de la lista en pestaña Global
- **WHEN** se renderiza una fila de la lista en la pestaña Global
- **THEN** su dato contextual es el número de niveles superados de ese jugador, sin racha ni indicador de variación

#### Scenario: Fila de la lista en pestaña Camino
- **WHEN** se renderiza una fila de la lista en la pestaña Camino
- **THEN** su dato contextual indica si esa parada está superada por ese jugador, sin distancia, intentos ni indicador de variación
