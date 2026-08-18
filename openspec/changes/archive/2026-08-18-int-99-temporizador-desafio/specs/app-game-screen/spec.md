## ADDED Requirements

### Requirement: Cuenta atrás visible durante la fase de adivinar
La pantalla SHALL mostrar, en la capa fija del HUD, una barra de cuenta
atrás con etiqueta `m:ss` para el desafío actual, inicializada al
`segundos_por_desafio` del nivel en curso. La barra SHALL marcar el
desafío como mostrado (RPC `marcar_desafio_mostrado`) en el instante en que
se vuelve el actual —al arrancar el intento para el primero, al pulsar
"Siguiente" para los demás— y SHALL seguir corriendo con el toast de pista
abierto, igual que el resto del HUD. La barra SHALL mostrarse en teal
mientras quede más de la mitad del tiempo, en ámbar entre la mitad y una
quinta parte, y en rojo por debajo de una quinta parte. Al avanzar a un
desafío nuevo, la cuenta atrás SHALL reiniciarse a los segundos completos
del nivel.

#### Scenario: La cuenta atrás arranca con el desafío
- **WHEN** se muestra el primer desafío de un intento en un nivel con
  `segundos_por_desafio = 60`
- **THEN** la barra muestra "1:00" en teal y llama a
  `marcar_desafio_mostrado` para ese desafío

#### Scenario: La cuenta atrás cambia de color al bajar el tiempo
- **WHEN** quedan menos de la mitad de los segundos del nivel
- **THEN** la barra pasa a ámbar

#### Scenario: La cuenta atrás se pone roja cerca del final
- **WHEN** queda menos de una quinta parte de los segundos del nivel
- **THEN** la barra pasa a rojo

#### Scenario: La cuenta atrás sigue corriendo con la pista abierta
- **WHEN** el jugador tiene el toast de pista abierto
- **THEN** la cuenta atrás sigue descontando, visible por encima del toast

#### Scenario: Avanzar a un desafío nuevo reinicia la cuenta atrás
- **WHEN** el jugador pulsa "Siguiente" desde el revelado y pasa al
  desafío siguiente
- **THEN** la cuenta atrás vuelve a mostrar los segundos completos del
  nivel y llama a `marcar_desafio_mostrado` para el nuevo desafío

### Requirement: Comportamiento al agotar el tiempo
Cuando la cuenta atrás llega a 0 con un pin colocado, la pantalla SHALL
disparar la misma acción que "Confirmar" automáticamente, sin necesitar que
el jugador toque nada. Cuando llega a 0 sin ningún pin colocado, la
pantalla SHALL llamar a `responder_desafio` sin coordenadas y entrar en el
revelado del desafío con 0 puntos. En ese revelado sin pin, la pantalla
SHALL mostrar únicamente la ubicación real y los puntos (0), sin pin del
jugador, sin línea entre pines y sin contador de distancia.

#### Scenario: El tiempo se agota con un pin ya colocado
- **WHEN** la cuenta atrás llega a 0 y el jugador ya había colocado un pin
- **THEN** la pantalla envía esas coordenadas a `responder_desafio` igual
  que si el jugador hubiera pulsado "Confirmar", y entra en el revelado

#### Scenario: El tiempo se agota sin ningún pin colocado
- **WHEN** la cuenta atrás llega a 0 y no hay ningún pin colocado
- **THEN** la pantalla llama a `responder_desafio` sin coordenadas y entra
  en el revelado de ese desafío con 0 puntos

#### Scenario: El revelado sin pin no muestra distancia
- **WHEN** se muestra el revelado de un desafío respondido sin pin
- **THEN** la hoja de resultado muestra la ubicación real y 0 puntos, sin
  pin del jugador, sin línea y sin ninguna cifra de distancia

#### Scenario: Agotar el tiempo en el último desafío del intento
- **WHEN** el tiempo se agota (con o sin pin) en el último desafío del
  intento
- **THEN** el botón del revelado sigue rotulado "Ver resultados", igual
  que en cualquier otro revelado del último desafío

### Requirement: El revelado muestra el desglose del bonus por rapidez
La hoja de resultado del revelado SHALL mostrar, cuando corresponde a una
respuesta con pin colocado, el puntaje de precisión y, si es mayor que 0,
el bonus por rapidez por separado (p. ej. "+80 por rapidez"), además del
total. Cuando el bonus es 0, la hoja SHALL mostrar solo el puntaje de
precisión, sin una línea de bonus vacía o en cero.

#### Scenario: El revelado muestra un bonus por rapidez positivo
- **WHEN** se muestra el revelado de una respuesta con pin colocado cuyo
  `puntos_bonus` es mayor que 0
- **THEN** la hoja de resultado muestra el puntaje de precisión y una línea
  de bonus con el valor de `puntos_bonus`, además del total

#### Scenario: El revelado no muestra una línea de bonus si no hubo bonus
- **WHEN** se muestra el revelado de una respuesta con pin colocado cuyo
  `puntos_bonus` es 0 (tiempo agotado o respuesta en el suelo de precisión)
- **THEN** la hoja de resultado muestra el puntaje de precisión sin ninguna
  línea de bonus
