## ADDED Requirements

### Requirement: Bienvenida personalizada al jugador reconocido
Cuando el splash resuelve la sesión con éxito y ya existe un apodo guardado en el dispositivo, la app SHALL mostrar una pantalla de bienvenida que salude al jugador por su apodo guardado y muestre un avatar con la inicial de ese apodo, en vez de navegar directamente al Mapa de temáticas.

#### Scenario: Jugador reconocido abre la app
- **WHEN** la sesión se resuelve con éxito y ya existe un apodo guardado en el dispositivo
- **THEN** la app navega a la pantalla de bienvenida de regreso
- **AND** se muestra el saludo "¡Hola, {apodo guardado}!" junto con un avatar con la inicial del apodo

### Requirement: Resumen de progreso con datos reales
La pantalla de bienvenida de regreso SHALL mostrar únicamente datos de progreso ya disponibles a través de `CaminoGateway` (vista `camino_jugador`): puntos totales acumulados, número de niveles superados, estrellas acumuladas, y el nombre del nivel/temática siguiente junto con la fracción de estrellas acumuladas sobre las requeridas para desbloquearlo. La pantalla NO SHALL mostrar ningún indicador para el que no exista una fuente de datos real, en particular un récord global de puntos, una racha de días consecutivos jugados o la fecha de la última partida.

#### Scenario: Jugador con progreso ve su resumen
- **WHEN** se muestra la pantalla de bienvenida de regreso para un jugador con progreso registrado
- **THEN** se muestran sus puntos totales, sus niveles superados y sus estrellas acumuladas
- **AND** se muestra el nombre del siguiente nivel/temática junto con la fracción de estrellas acumuladas sobre las requeridas para desbloquearlo

#### Scenario: No se inventan métricas sin fuente de datos
- **WHEN** se muestra la pantalla de bienvenida de regreso
- **THEN** no se muestra ningún indicador de récord global de puntos, racha de días jugados ni fecha de última partida

### Requirement: Continuar la partida
La pantalla de bienvenida de regreso SHALL ofrecer una acción principal "Seguir jugando" que navegue directamente al Mapa de temáticas.

#### Scenario: El jugador pulsa seguir jugando
- **WHEN** el jugador pulsa "Seguir jugando"
- **THEN** la app navega al Mapa de temáticas

### Requirement: Cambiar de jugador
La pantalla de bienvenida de regreso SHALL ofrecer una acción secundaria "Cambiar de jugador" que borre el apodo guardado localmente en el dispositivo y muestre la pantalla de captura de apodo para introducir uno nuevo.

#### Scenario: El jugador pulsa cambiar de jugador
- **WHEN** el jugador pulsa "Cambiar de jugador"
- **THEN** se elimina el apodo guardado localmente en el dispositivo
- **AND** la app muestra la pantalla de captura de apodo en su estado de "primera vez"

### Requirement: Hueco preparado para vincular una cuenta
La pantalla de bienvenida de regreso SHALL mostrar un enlace secundario "Vincular una cuenta para no perder el progreso", visualmente presente pero sin acción asociada todavía.

#### Scenario: El jugador ve el enlace de vinculación
- **WHEN** se muestra la pantalla de bienvenida de regreso
- **THEN** es visible el enlace "Vincular una cuenta para no perder el progreso"
- **AND** pulsarlo no produce ningún efecto ni navegación
