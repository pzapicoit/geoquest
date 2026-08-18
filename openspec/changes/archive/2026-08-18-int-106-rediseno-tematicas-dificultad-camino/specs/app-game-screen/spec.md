## MODIFIED Requirements

### Requirement: Entrar a la pantalla de juego arranca un intento real

Al montarse, la pantalla de juego de la parada SHALL llamar a la RPC
`iniciar_intento_parada` con el `camino_id` de la parada tocada, y usar el
`intento_id` y la lista de desafíos de la respuesta para su contenido. La
pantalla SHALL mostrar un estado de carga mientras la llamada está en
curso.

#### Scenario: La pantalla arranca el intento al abrirse

- **WHEN** el jugador toca una parada desbloqueada del camino y se abre la
  pantalla de juego
- **THEN** la app llama a `iniciar_intento_parada(camino_id)` y, al recibir
  respuesta, deja de mostrar el estado de carga y muestra la pista del
  primer desafío recibido

#### Scenario: Arrancar el intento falla

- **WHEN** la llamada a `iniciar_intento_parada` falla (sin red, parada
  inactiva u otro error)
- **THEN** la pantalla muestra un mensaje de error y una opción para
  reintentar, sin dejar ningún estado de carga colgado

#### Scenario: El intento no tiene desafíos disponibles

- **WHEN** `iniciar_intento_parada` responde correctamente pero con una
  lista de desafíos vacía
- **THEN** la pantalla muestra un mensaje explicando que el nivel no
  tiene desafíos disponibles, con opción de reintentar, en vez de
  fallar al intentar mostrar un desafío inexistente

### Requirement: Avanzar desde el revelado es un acto del jugador

El revelado SHALL ofrecer un botón que continúe la partida, rotulado
"Siguiente" cuando queden desafíos por jugar y "Ver resultados" cuando el
revelado sea el del último desafío del intento. Solo pulsarlo SHALL sacar
al jugador del revelado.

Al pulsar "Siguiente", la pantalla SHALL mostrar la pista del desafío
siguiente, con el mapa sin ningún pin y sin la línea del revelado
anterior. Al pulsar "Ver resultados", la pantalla SHALL cerrar el intento
(`cerrar_intento_parada`) y, al recibir el resultado, navegar a la pantalla
de resumen del nivel en vez de volver directamente al camino de niveles.
Mientras esa llamada está en curso, "Ver resultados" SHALL quedar
deshabilitado para no cerrar el mismo intento dos veces; si falla, la
pantalla SHALL avisar del fallo y conservar el revelado en pantalla para
reintentar.

El revelado SHALL ofrecer además una acción para repetir la animación, que
relance la secuencia completa desde el principio sin volver a llamar al
servidor.

#### Scenario: Avanzar al siguiente desafío

- **WHEN** el jugador está en el revelado del desafío 1 de 3 y pulsa
  "Siguiente"
- **THEN** la pantalla muestra la pista del desafío 2 de 3 y el mapa vuelve
  a no tener ningún pin ni línea

#### Scenario: El revelado no avanza solo

- **WHEN** la secuencia del revelado termina y el jugador no pulsa nada
- **THEN** la pantalla sigue mostrando el resultado, sin avanzar al desafío
  siguiente ni cerrar el intento

#### Scenario: Revelado del último desafío cierra el intento

- **WHEN** el revelado es el del último desafío del intento y el jugador
  pulsa "Ver resultados"
- **THEN** la pantalla llama a `cerrar_intento_parada` con ese intento y,
  al recibir el resultado, navega a la pantalla de resumen del nivel

#### Scenario: Cerrar el intento falla al pulsar "Ver resultados"

- **WHEN** la llamada a `cerrar_intento_parada` disparada por "Ver
  resultados" falla
- **THEN** la pantalla avisa del fallo, mantiene el revelado del último
  desafío en pantalla y vuelve a habilitar "Ver resultados"

#### Scenario: Repetir la animación

- **WHEN** el jugador pulsa la acción de repetir la animación
- **THEN** la secuencia vuelve a correr desde el principio, con los
  contadores otra vez desde 0, sin llamar de nuevo a `responder_desafio` ni
  a `cerrar_intento_parada`, y sin alterar el puntaje acumulado del intento

### Requirement: Cuenta atrás visible durante la fase de adivinar
La pantalla SHALL mostrar, en la capa fija del HUD, una barra de cuenta
atrás con etiqueta `m:ss` para el desafío actual, inicializada al
`segundos_por_desafio` efectivo de la parada en curso (override propio, o
el de `dificultad_defaults` para su dificultad si no tiene override). La
barra SHALL marcar el desafío como mostrado (RPC `marcar_desafio_mostrado`)
en el instante en que se vuelve el actual —al arrancar el intento para el
primero, al pulsar "Siguiente" para los demás— y SHALL seguir corriendo con
el toast de pista abierto, igual que el resto del HUD. La barra SHALL
mostrarse en teal mientras quede más de la mitad del tiempo, en ámbar entre
la mitad y una quinta parte, y en rojo por debajo de una quinta parte. Al
avanzar a un desafío nuevo, la cuenta atrás SHALL reiniciarse a los
segundos completos efectivos de la parada.

#### Scenario: La cuenta atrás arranca con el desafío
- **WHEN** se muestra el primer desafío de un intento en una parada cuyo
  `segundos_por_desafio` efectivo es 60
- **THEN** la barra muestra "1:00" en teal y llama a
  `marcar_desafio_mostrado` para ese desafío

#### Scenario: La cuenta atrás cambia de color al bajar el tiempo
- **WHEN** quedan menos de la mitad de los segundos efectivos de la parada
- **THEN** la barra pasa a ámbar

#### Scenario: La cuenta atrás se pone roja cerca del final
- **WHEN** queda menos de una quinta parte de los segundos efectivos de la
  parada
- **THEN** la barra pasa a rojo

#### Scenario: La cuenta atrás sigue corriendo con la pista abierta
- **WHEN** el jugador tiene el toast de pista abierto
- **THEN** la cuenta atrás sigue descontando, visible por encima del toast

#### Scenario: Avanzar a un desafío nuevo reinicia la cuenta atrás
- **WHEN** el jugador pulsa "Siguiente" desde el revelado y pasa al
  desafío siguiente
- **THEN** la cuenta atrás vuelve a mostrar los segundos completos
  efectivos de la parada y llama a `marcar_desafio_mostrado` para el nuevo
  desafío
