# app-ranking Specification

## Purpose
Pantalla "Clasificación" de la app móvil: tres pestañas navegables (Global, Camino, Temática) sobre las clasificaciones entre jugadores de `player-ranking`, con podio, lista scrollable, fila fija de la posición propia y punto de entrada desde la navegación existente. Creada al archivar el cambio int-110-pantalla-ranking; la pestaña "Camino" se renombró desde "Nivel" en int-110-pantalla-ranking-delta-1.

## Requirements

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

El dato contextual SHALL ser, según la pestaña: número de niveles superados en la pestaña Global; si esa parada está superada (`superado`) en la pestaña Camino; número de niveles superados de esa temática en la pestaña Temática. El sistema NO SHALL mostrar datos de racha, número de intentos ni porcentaje de acierto de otros jugadores, ni ningún indicador de variación (▲/▼), por no estar disponibles en las funciones de clasificación actuales.

#### Scenario: Fila de la lista en pestaña Global
- **WHEN** se renderiza una fila de la lista en la pestaña Global
- **THEN** su dato contextual es el número de niveles superados de ese jugador, sin racha ni indicador de variación

#### Scenario: Fila de la lista en pestaña Camino
- **WHEN** se renderiza una fila de la lista en la pestaña Camino
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
