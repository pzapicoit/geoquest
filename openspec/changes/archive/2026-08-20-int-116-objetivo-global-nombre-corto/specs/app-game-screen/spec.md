## MODIFIED Requirements

### Requirement: Toast de pista muestra el contenido según el tipo de desafío

La pantalla SHALL mostrar el contenido del desafío actual en una tarjeta
superpuesta (toast) sobre un fondo oscurecido, eligiendo qué mostrar según
el campo `tipo` del desafío: una imagen a buen tamaño cuando `tipo` es
`imagen`, un vídeo reproduciéndose cuando `tipo` es `video`, o el texto de
la pregunta en tamaño grande cuando `tipo` es `pregunta_texto`.

El toast SHALL llevar una cabecera que identifique el tipo de pista y su
número dentro del intento, un botón de cerrar en esa cabecera, el
`objetivo_global` de la temática de la parada junto con el `nombre` del
desafío actual, un pie explicativo de qué se le pide al jugador, y el
botón "Listo, voy a adivinar". Tocar el fondo oscurecido SHALL cerrar el
toast igual que cualquiera de sus botones de cierre.

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

#### Scenario: Cabecera del toast según el tipo

- **WHEN** se muestra el toast del tercer desafío de un intento y su `tipo`
  es `video`
- **THEN** la cabecera del toast lo identifica como pista de vídeo y como
  la número 3

#### Scenario: El toast muestra el objetivo global junto al nombre del desafío

- **WHEN** se muestra el toast de un desafío cuyo `nombre` es "Torre
  Eiffel" en una parada cuya temática tiene `objetivo_global = '¿Dónde
  está este monumento?'`
- **THEN** el toast muestra ambos textos, para cualquiera de los tres
  tipos de contenido (imagen, vídeo o pregunta de texto)

#### Scenario: Cerrar tocando el fondo

- **WHEN** el toast está abierto y el jugador toca el fondo oscurecido
  fuera de la tarjeta
- **THEN** el toast se cierra y la pantalla queda en la fase de adivinar
