## ADDED Requirements

### Requirement: Precarga de las imágenes del intento

En cuanto `iniciar_intento_parada` responde, la pantalla de juego SHALL
lanzar la precarga de las `imagen_url` de todos los desafíos del intento con
`tipo = 'imagen'`, en el mismo orden en que se van a jugar, para que la
imagen de cada parada ya esté en caché cuando el jugador llegue a ella.

La precarga SHALL ser de fondo: la pantalla SHALL NOT retrasar, bloquear ni
alterar la aparición de la pista del primer desafío, el arranque de su cuenta
atrás ni ninguna otra parte de la partida mientras la precarga está en curso.
La pantalla SHALL NOT mostrar ningún indicador de progreso, mensaje ni estado
de carga propio de la precarga.

Un fallo de precarga de cualquier imagen SHALL quedar contenido: no muestra
error, no aborta la precarga de las demás imágenes y no cambia el
comportamiento del desafío afectado, que se seguirá cargando a demanda —con
su tratamiento de error de siempre— cuando el jugador llegue a él.

La precarga SHALL usar el mismo identificador de imagen que el pintado a
demanda (la propia URL), de forma que llegar a la parada sea un acierto de
caché y no una segunda petición a la red.

Si el jugador sale de la pantalla antes de que la precarga termine, lo que
quede pendiente SHALL NOT tocar el estado de la pantalla ni provocar error.

#### Scenario: Al arrancar el intento se precargan todas las imágenes

- **WHEN** `iniciar_intento_parada` responde con un intento cuyos desafíos
  incluyen varios de `tipo = 'imagen'`
- **THEN** la pantalla pide la precarga de la `imagen_url` de cada uno de
  esos desafíos, incluida la del primero y las de los posteriores, en el
  orden de juego

#### Scenario: Los desafíos sin imagen no se precargan

- **WHEN** el intento incluye desafíos de `tipo = 'video'` o
  `tipo = 'pregunta_texto'`
- **THEN** la pantalla no pide ninguna precarga para ellos, y solo precarga
  las URLs de los desafíos de tipo imagen

#### Scenario: La partida no espera a la precarga

- **WHEN** el intento se recibe y la precarga de sus imágenes queda en curso
  sin resolverse
- **THEN** la pista del primer desafío ya está visible y su cuenta atrás en
  marcha, sin indicador de progreso de precarga en pantalla

#### Scenario: Una imagen falla al precargarse

- **WHEN** la precarga de la imagen de un desafío falla (URL rota, 404 o sin
  red)
- **THEN** la pantalla no muestra ningún error por ello, sigue precargando
  las imágenes de los demás desafíos, y al llegar a ese desafío su pista se
  comporta igual que si nunca hubiera habido precarga

#### Scenario: Llegar a una parada ya precargada no vuelve a la red

- **WHEN** el jugador avanza a un desafío de imagen cuya precarga ya terminó
- **THEN** la pista muestra la imagen desde la caché de imágenes, sin una
  petición de red nueva ni hueco de carga visible

#### Scenario: Salir del nivel con precargas pendientes

- **WHEN** el jugador abandona la pantalla de juego mientras quedan
  precargas sin resolver
- **THEN** las precargas que se resuelvan después no modifican estado ni
  provocan error
