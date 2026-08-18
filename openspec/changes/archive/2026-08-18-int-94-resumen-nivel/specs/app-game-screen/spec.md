## MODIFIED Requirements

### Requirement: Avanzar desde el revelado es un acto del jugador

El revelado SHALL ofrecer un botón que continúe la partida, rotulado
"Siguiente" cuando queden desafíos por jugar y "Ver resultados" cuando el
revelado sea el del último desafío del intento. Solo pulsarlo SHALL sacar
al jugador del revelado.

Al pulsar "Siguiente", la pantalla SHALL mostrar la pista del desafío
siguiente, con el mapa sin ningún pin y sin la línea del revelado
anterior. Al pulsar "Ver resultados", la pantalla SHALL cerrar el intento
(`cerrar_intento_nivel`) y, al recibir el resultado, navegar a la pantalla
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
- **THEN** la pantalla llama a `cerrar_intento_nivel` con ese intento y,
  al recibir el resultado, navega a la pantalla de resumen del nivel

#### Scenario: Cerrar el intento falla al pulsar "Ver resultados"

- **WHEN** la llamada a `cerrar_intento_nivel` disparada por "Ver
  resultados" falla
- **THEN** la pantalla avisa del fallo, mantiene el revelado del último
  desafío en pantalla y vuelve a habilitar "Ver resultados"

#### Scenario: Repetir la animación

- **WHEN** el jugador pulsa la acción de repetir la animación
- **THEN** la secuencia vuelve a correr desde el principio, con los
  contadores otra vez desde 0, sin llamar de nuevo a `responder_desafio` ni
  a `cerrar_intento_nivel`, y sin alterar el puntaje acumulado del intento
