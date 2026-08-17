## ADDED Requirements

### Requirement: Entrar a la pantalla de juego arranca un intento real

Al montarse, la pantalla de juego del nivel SHALL llamar a la RPC
`iniciar_intento_nivel` con el `nivel_id` de la parada tocada, y usar el
`intento_id` y la lista de desafíos de la respuesta para su contenido. La
pantalla SHALL mostrar un estado de carga mientras la llamada está en
curso.

#### Scenario: La pantalla arranca el intento al abrirse

- **WHEN** el jugador toca una parada desbloqueada del camino y se abre la
  pantalla de juego
- **THEN** la app llama a `iniciar_intento_nivel(nivel_id)` y, al recibir
  respuesta, deja de mostrar el estado de carga y muestra la pista del
  primer desafío recibido

#### Scenario: Arrancar el intento falla

- **WHEN** la llamada a `iniciar_intento_nivel` falla (sin red, nivel
  inactivo u otro error)
- **THEN** la pantalla muestra un mensaje de error y una opción para
  reintentar, sin dejar ningún estado de carga colgado

#### Scenario: El intento no tiene desafíos disponibles

- **WHEN** `iniciar_intento_nivel` responde correctamente pero con una
  lista de desafíos vacía
- **THEN** la pantalla muestra un mensaje explicando que el nivel no
  tiene desafíos disponibles, con opción de reintentar, en vez de
  fallar al intentar mostrar un desafío inexistente

### Requirement: Toast de pista muestra el contenido según el tipo de desafío

La pantalla SHALL mostrar el contenido del desafío actual en una tarjeta
superpuesta (toast), eligiendo qué mostrar según el campo `tipo` del
desafío: una imagen a buen tamaño cuando `tipo` es `imagen`, un vídeo
reproduciéndose cuando `tipo` es `video`, o el texto de la pregunta en
tamaño grande cuando `tipo` es `pregunta_texto`.

#### Scenario: Desafío de tipo imagen

- **WHEN** el desafío actual tiene `tipo = 'imagen'`
- **THEN** el toast muestra `imagen_url` a buen tamaño y no intenta
  reproducir ningún vídeo ni mostrar texto de pregunta

#### Scenario: Desafío de tipo video

- **WHEN** el desafío actual tiene `tipo = 'video'`
- **THEN** el toast reproduce `video_url`

#### Scenario: El video de un desafío no puede reproducirse

- **WHEN** el desafío actual tiene `tipo = 'video'` y la reproducción
  falla al inicializarse (URL rota, sin red)
- **THEN** el toast muestra un aviso de que el vídeo no está disponible,
  en vez de quedarse en una pantalla en negro sin explicación

#### Scenario: Desafío de tipo pregunta de texto

- **WHEN** el desafío actual tiene `tipo = 'pregunta_texto'`
- **THEN** el toast muestra `texto_pregunta` en tamaño grande

### Requirement: Progreso y puntaje del intento visibles

La pantalla SHALL mostrar en todo momento, junto al toast, el progreso
dentro del intento actual como "Desafío X de N" (X = posición del
desafío mostrado, N = total de desafíos del intento) y el puntaje
acumulado del intento actual.

#### Scenario: Progreso con varios desafíos

- **WHEN** el intento tiene 6 desafíos y se muestra el primero
- **THEN** la pantalla muestra el texto de progreso "Desafío 1 de 6"

#### Scenario: Puntaje al recién arrancar el intento

- **WHEN** el intento se acaba de crear y todavía no se ha resuelto
  ningún desafío
- **THEN** la pantalla muestra el puntaje acumulado del intento como 0

### Requirement: Cerrar el toast revela el estado de mapa a pantalla completa

La pantalla SHALL ofrecer un botón para cerrar el toast ("Listo, voy a
adivinar"). Al tocarlo, el toast SHALL dejar de mostrarse y la pantalla
SHALL pasar a un estado de mapa a pantalla completa.

#### Scenario: Cerrar el toast

- **WHEN** el jugador toca "Listo, voy a adivinar"
- **THEN** el toast deja de mostrarse y la pantalla queda en el estado de
  mapa a pantalla completa
