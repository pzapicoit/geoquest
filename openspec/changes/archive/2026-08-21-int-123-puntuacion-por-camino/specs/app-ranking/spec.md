## MODIFIED Requirements

### Requirement: Pantalla única con tres pestañas de clasificación
El sistema SHALL mostrar una pantalla "Clasificación" con tres pestañas navegables — Global, Camino y Temática — donde cambiar de pestaña recarga la clasificación correspondiente sin salir de la pantalla.

El subtítulo de la pestaña Global SHALL no describir la puntuación como un acumulado histórico: desde que `clasificacion_global` agrega el mejor intento por parada, esa etiqueta describe algo que el sistema ya no hace.

#### Scenario: El jugador cambia de pestaña
- **WHEN** el jugador pulsa la pestaña "Temática" estando en "Global"
- **THEN** la pantalla carga y muestra `clasificacion_por_tematica` para la temática seleccionada, sin navegar a otra pantalla

#### Scenario: Cabecera contextual por pestaña
- **WHEN** la pestaña activa es Global, o Camino/Temática con una tarjeta abierta
- **THEN** el subtítulo de la cabecera refleja esa selección (p. ej. "Global · mejor intento por nivel", "Nivel N · <temática de esa parada>", "<Temática> · ranking") y la cabecera muestra siempre los puntos totales del propio jugador

#### Scenario: El subtítulo de Global no promete un acumulado histórico
- **WHEN** la pestaña activa es Global
- **THEN** su subtítulo no dice "acumulado histórico" ni ninguna variante que sugiera que repetir un nivel suma puntos

#### Scenario: Los puntos de la cabecera coinciden con la Home
- **WHEN** el jugador abre la Clasificación desde la Home
- **THEN** los puntos totales de la cabecera son los mismos que muestra la píldora de la Home, por venir del mismo `camino_jugador` ya cargado
