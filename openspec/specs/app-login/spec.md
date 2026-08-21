# app-login Specification

## Purpose
TBD - created by archiving change int-108-pantalla-entrada-login. Update Purpose after archive.

## Requirements

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

La pantalla de bienvenida de regreso SHALL ofrecer una acción secundaria "Cambiar
de jugador" que borre el apodo guardado en el dispositivo, suelte la sesión del
jugador activo y muestre la pantalla de acceso. Soltar la sesión es lo que hace
que el apodo que se introduzca después entre en su propio perfil en vez de
renombrar el del jugador anterior.

Cuando el jugador activo **no tiene contraseña**, la acción NO SHALL soltar su
sesión sin más: soltarla equivale a perder ese perfil, porque no queda ninguna
credencial con la que volver a él. En ese caso SHALL pedir que se le ponga una
contraseña antes de continuar, y SHALL ofrecer descartar ese jugador como una
decisión explícita.

El progreso mostrado tras cambiar de jugador SHALL corresponder al jugador que
entra: la pantalla no SHALL reutilizar los datos de camino, puntuación ni
comodines cargados para el jugador anterior.

#### Scenario: Cambiar de jugador teniendo contraseña
- **WHEN** el jugador activo tiene contraseña y pulsa "Cambiar de jugador"
- **THEN** se elimina el apodo guardado localmente en el dispositivo
- **AND** su sesión deja de estar activa
- **AND** la app muestra la pantalla de acceso, con los apodos que el dispositivo
  recuerde

#### Scenario: Cambiar de jugador sin tener contraseña
- **WHEN** el jugador activo no tiene contraseña y pulsa "Cambiar de jugador"
- **THEN** la app le pide ponerse una contraseña para poder volver a este perfil
- **AND** su sesión sigue activa mientras no la ponga o no descarte el jugador
  explícitamente

#### Scenario: Descartar explícitamente un jugador sin contraseña
- **WHEN** el jugador confirma que quiere descartar el jugador sin contraseña
- **THEN** la app suelta esa sesión y muestra la pantalla de acceso
- **AND** se le ha advertido antes de que ese progreso no se podrá recuperar

#### Scenario: El perfil anterior nunca se renombra
- **WHEN** tras cambiar de jugador se introduce cualquier apodo, exista ya o esté
  libre
- **THEN** el perfil del jugador anterior conserva su apodo, su puntuación y su
  progreso
- **AND** su apodo sigue apareciendo en la clasificación

#### Scenario: El progreso mostrado es del jugador que entra
- **WHEN** se completa un cambio de jugador y se muestra la bienvenida de regreso
- **THEN** el resumen de progreso corresponde al jugador que acaba de entrar
- **AND** no se muestran los puntos, niveles ni estrellas del jugador anterior

### Requirement: Hueco preparado para vincular una cuenta

La pantalla de bienvenida de regreso SHALL mostrar un enlace secundario que lleve
a proteger el progreso, y su destino SHALL depender de si el jugador ya tiene
contraseña: para quien no la tiene, ponerse una es la acción real y disponible;
para quien ya la tiene, el enlace sigue anunciando la vinculación de una cuenta
externa, todavía sin acción asociada.

#### Scenario: Jugador sin contraseña
- **WHEN** se muestra la bienvenida de regreso a un jugador sin contraseña
- **THEN** es visible un enlace para ponerse una contraseña y no perder el
  progreso
- **AND** pulsarlo lleva a establecerla

#### Scenario: Jugador con contraseña
- **WHEN** se muestra la bienvenida de regreso a un jugador con contraseña
- **THEN** es visible el enlace "Vincular una cuenta para no perder el progreso"
- **AND** pulsarlo no produce ningún efecto ni navegación

