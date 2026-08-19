## ADDED Requirements

### Requirement: Pantalla única con tres pestañas de clasificación
El sistema SHALL mostrar una pantalla "Clasificación" con tres pestañas navegables — Global, Nivel y Temática — donde cambiar de pestaña recarga la clasificación correspondiente sin salir de la pantalla.

#### Scenario: El jugador cambia de pestaña
- **WHEN** el jugador pulsa la pestaña "Temática" estando en "Global"
- **THEN** la pantalla carga y muestra `clasificacion_por_tematica` para la temática seleccionada, sin navegar a otra pantalla

#### Scenario: Cabecera contextual por pestaña
- **WHEN** la pestaña activa es Global, Nivel o Temática
- **THEN** el subtítulo de la cabecera refleja esa pestaña (p. ej. "Global · acumulado histórico", "Nivel N · <temática de esa parada>", "<Temática> · ranking") y la cabecera muestra siempre los puntos totales del propio jugador

### Requirement: Selector de parada o temática en las pestañas Nivel y Temática
El sistema SHALL mostrar, solo en las pestañas Nivel y Temática, un selector de chips horizontales para elegir la parada del camino o la temática concreta a consultar; la pestaña Global no muestra este selector.

#### Scenario: Selector visible en Nivel
- **WHEN** la pestaña activa es "Nivel"
- **THEN** se muestran chips con cada parada del camino disponible, y seleccionar uno recarga `clasificacion_por_camino` para esa parada

#### Scenario: Selector visible en Temática
- **WHEN** la pestaña activa es "Temática"
- **THEN** se muestran chips con cada temática disponible, y seleccionar uno recarga `clasificacion_por_tematica` para esa temática

#### Scenario: Selector ausente en Global
- **WHEN** la pestaña activa es "Global"
- **THEN** no se muestra el selector de chips

### Requirement: Podio para el top 3
El sistema SHALL destacar en un podio las 3 primeras posiciones de la clasificación activa, mostrando para cada una un avatar (inicial del nombre), el nombre y la puntuación, distinguiendo visualmente 1º/2º/3º puesto.

#### Scenario: Clasificación con 3 o más jugadores puntuados
- **WHEN** la clasificación activa devuelve 3 o más filas con puntuación
- **THEN** las 3 primeras posiciones se muestran en el podio y no se repiten en la lista scrollable

#### Scenario: Clasificación con menos de 3 jugadores puntuados
- **WHEN** la clasificación activa devuelve menos de 3 filas con puntuación
- **THEN** el podio muestra únicamente los puestos existentes, sin plazas ficticias

### Requirement: Lista scrollable del resto de posiciones
El sistema SHALL mostrar en una lista scrollable las posiciones no incluidas en el podio, cada una con puesto, avatar, nombre, dato contextual soportado por el backend y puntuación.

El dato contextual SHALL ser, según la pestaña: número de niveles superados en la pestaña Global; si esa parada está superada (`superado`) en la pestaña Nivel; número de niveles superados de esa temática en la pestaña Temática. El sistema NO SHALL mostrar datos de racha, número de intentos ni porcentaje de acierto de otros jugadores, ni ningún indicador de variación (▲/▼), por no estar disponibles en las funciones de clasificación actuales.

#### Scenario: Fila de la lista en pestaña Global
- **WHEN** se renderiza una fila de la lista en la pestaña Global
- **THEN** su dato contextual es el número de niveles superados de ese jugador, sin racha ni indicador de variación

#### Scenario: Fila de la lista en pestaña Nivel
- **WHEN** se renderiza una fila de la lista en la pestaña Nivel
- **THEN** su dato contextual indica si esa parada está superada por ese jugador, sin distancia, intentos ni indicador de variación

### Requirement: Fila fija con la posición propia
El sistema SHALL mostrar siempre, fija al pie de la pantalla, la fila con la posición y puntuación del propio jugador en la clasificación activa, incluso cuando esa posición quede fuera de las filas cargadas en el podio y la lista.

#### Scenario: El jugador está fuera del top cargado
- **WHEN** la posición del propio jugador no está entre las filas devueltas para el podio o la lista
- **THEN** la fila fija al pie sigue mostrando su posición real y puntuación, usando la fila marcada `es_usuario_actual = true` que devuelve la función de clasificación

#### Scenario: El jugador sin puntuación agregable en la pestaña activa
- **WHEN** la función de clasificación devuelve la fila del jugador con `posicion = null` (sin puntuación agregable en esa clasificación)
- **THEN** la fila fija al pie muestra un estado "sin posición todavía" en vez de un número de puesto, junto con su puntuación en 0

### Requirement: Estados de carga y vacío por pestaña
El sistema SHALL mostrar un estado de carga mientras se resuelve la consulta de la pestaña activa, y un estado vacío diferenciado cuando la clasificación no tiene ningún jugador con puntuación agregable.

#### Scenario: Cambio de pestaña o de chip mientras carga
- **WHEN** el jugador cambia de pestaña o de chip (parada/temática)
- **THEN** se muestra un estado de carga para esa pestaña/chip hasta que la respuesta llega, sin mostrar datos obsoletos de la selección anterior

#### Scenario: Clasificación sin ningún jugador puntuado
- **WHEN** la función de clasificación de la pestaña/chip activo no devuelve ninguna fila con puntuación agregable aparte de la fila del propio jugador
- **THEN** se muestra un estado vacío explicando que todavía no hay clasificación para esa selección, y la fila fija propia sigue visible

### Requirement: Acceso a la pantalla desde la navegación de la app
El sistema SHALL exponer un punto de entrada a la pantalla de Clasificación desde la navegación existente de la app, accesible sin pasos intermedios innecesarios.

#### Scenario: El jugador navega a Clasificación
- **WHEN** el jugador interactúa con el punto de entrada de Clasificación en la navegación principal
- **THEN** la app navega a la pantalla de Clasificación abriendo por defecto la pestaña Global
