## ADDED Requirements

### Requirement: Las fases de la pantalla de juego entran y salen con transición
Ningún elemento de la pantalla de juego SHALL aparecer o desaparecer sin transición al cambiar de fase (pista, adivinar, revelado). La tarjeta de pista y la hoja del revelado SHALL entrar y salir deslizándose. Los controles de adivinar, la bandeja de comodines y los avisos SHALL entrar y salir con un fundido. Las duraciones y curvas SHALL salir de la base de movimiento común (`app-motion`).

#### Scenario: Cerrar la pista
- **WHEN** el jugador cierra la tarjeta de pista
- **THEN** la tarjeta sale deslizándose y desvaneciéndose, y los controles de adivinar y la bandeja aparecen con un fundido

#### Scenario: Confirmar una respuesta
- **WHEN** el jugador confirma su respuesta y empieza el revelado
- **THEN** los controles de adivinar y la bandeja desaparecen con un fundido y la hoja del revelado entra deslizándose desde abajo

#### Scenario: Un aviso aparece y se va
- **WHEN** la pantalla muestra un aviso temporal (por ejemplo, el resultado de un comodín)
- **THEN** el aviso entra con un fundido y, al caducar, sale con otro fundido en vez de desaparecer de golpe

### Requirement: Paso de un desafío al siguiente
Al continuar desde el revelado a un desafío que no es el último, la hoja del revelado SHALL salir antes de que entre la tarjeta de pista del siguiente desafío, de modo que el jugador perciba el cambio de desafío como un paso y no como un salto.

#### Scenario: Continuar al siguiente desafío
- **WHEN** el jugador pulsa continuar en el revelado de un desafío que no es el último
- **THEN** la hoja del revelado sale y, a continuación, entra la tarjeta de pista del siguiente desafío

### Requirement: El pin cae al colocarlo
Cada vez que el jugador coloca o mueve el pin, el pin SHALL aparecer con una caída breve y un pequeño rebote en su nueva posición.

#### Scenario: Colocar el pin
- **WHEN** el jugador toca un punto del mapa
- **THEN** el pin aparece en ese punto cayendo con un pequeño rebote

### Requirement: Respuesta háptica en los momentos clave
En los dispositivos que lo admiten, la pantalla de juego SHALL vibrar de forma leve al colocar o mover el pin, de forma media al confirmar una respuesta y con un patrón de éxito cuando el contador de puntos del revelado termina en una respuesta con puntos. En las plataformas sin vibración (web) SHALL seguir funcionando igual, sin vibrar.

#### Scenario: Confirmar en un móvil
- **WHEN** el jugador pulsa Confirmar en un móvil
- **THEN** el móvil vibra con una intensidad media

#### Scenario: Revelado con puntos
- **WHEN** el contador de puntos del revelado termina de contar una respuesta que suma puntos
- **THEN** el móvil vibra una vez con el patrón de éxito

#### Scenario: Revelado sin puntos
- **WHEN** el contador termina en una respuesta de 0 puntos
- **THEN** el móvil no vibra con el patrón de éxito

### Requirement: Los botones responden al pulsarlos
Los botones principales de la pantalla de juego (Confirmar, Ver la pista, Listo, Continuar y los botones de cristal del HUD) SHALL reducir ligeramente su escala mientras se mantienen pulsados y recuperarla al soltarlos. Un botón deshabilitado SHALL NOT reaccionar.

#### Scenario: Pulsar Confirmar
- **WHEN** el jugador mantiene el dedo sobre Confirmar con un pin colocado
- **THEN** el botón se encoge ligeramente y vuelve a su tamaño al soltarlo

#### Scenario: Botón deshabilitado
- **WHEN** el jugador pulsa Confirmar sin haber colocado el pin
- **THEN** el botón no cambia de escala

### Requirement: Cargas con el estilo del juego
Mientras se arranca el intento, la pantalla SHALL mostrar un estado de carga con el estilo visual del juego en vez del indicador circular por defecto de la plataforma. Mientras se descarga la imagen de una pista o de la miniatura del revelado, su hueco SHALL mostrar un fondo de carga animado, y la imagen SHALL aparecer con un fundido al llegar. Una imagen que ya estaba en caché SHALL mostrarse directamente, sin fundido.

#### Scenario: Arrancar el intento
- **WHEN** la pantalla de juego espera la respuesta de `iniciar_intento_parada`
- **THEN** se ve un estado de carga con el estilo del juego, no el indicador circular por defecto

#### Scenario: Imagen de pista en red lenta
- **WHEN** la tarjeta de pista se abre y su imagen todavía no ha llegado
- **THEN** el hueco de la imagen muestra el fondo de carga animado y, al llegar la imagen, esta aparece con un fundido

#### Scenario: Imagen ya precargada
- **WHEN** la tarjeta de pista se abre y su imagen ya está en la caché de imágenes por la precarga
- **THEN** la imagen se ve directamente, sin fondo de carga ni fundido

### Requirement: Reducir movimiento en la pantalla de juego
Con «reducir movimiento» activo, las animaciones de la pantalla de juego SHALL limitarse a fundidos: sin desplazamientos, cambios de escala ni rebotes, y con el fondo de carga quieto. La vibración SHALL mantenerse.

#### Scenario: Cerrar la pista con reducir movimiento
- **WHEN** el jugador tiene activado «reducir movimiento» y cierra la tarjeta de pista
- **THEN** la tarjeta desaparece con un fundido, sin desplazarse ni escalar

#### Scenario: Colocar el pin con reducir movimiento
- **WHEN** el jugador tiene activado «reducir movimiento» y coloca el pin
- **THEN** el pin aparece en su posición sin caída ni rebote
