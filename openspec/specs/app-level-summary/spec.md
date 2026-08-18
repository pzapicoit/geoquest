# app-level-summary Specification

## Purpose
TBD - created by archiving change int-94-resumen-nivel. Update Purpose after archive.

## Requirements

### Requirement: El resumen cierra el intento y muestra su resultado

La app SHALL cerrar el intento (`cerrar_intento_parada`) al llegar al
revelado del último desafío y pulsar "Ver resultados", y SHALL navegar a
la pantalla de resumen del nivel con el resultado devuelto, mostrando un
estado de carga en el botón mientras la llamada está en curso.

#### Scenario: Cerrar el intento tras el último desafío

- **WHEN** el jugador pulsa "Ver resultados" en el revelado del último
  desafío del intento
- **THEN** la app llama a `cerrar_intento_parada` con ese intento y, al
  recibir respuesta, navega al resumen del nivel con el puntaje,
  superación y estrellas devueltas

#### Scenario: Cerrar el intento falla

- **WHEN** la llamada a `cerrar_intento_parada` falla (sin red, error del
  servidor)
- **THEN** la pantalla de juego avisa del fallo, conserva el revelado del
  último desafío en pantalla y vuelve a habilitar "Ver resultados" para
  reintentar, sin navegar al resumen

### Requirement: Resumen en estado superado

Cuando el intento cerrado quede `superado = true`, el resumen SHALL
mostrar: el nombre del nivel y un mensaje de celebración, el puntaje total
del intento, sus estrellas obtenidas (1 a 3) rellenándose una a una en
una animación, y un botón "Continuar" que vuelva al camino de niveles.
Cuando las estrellas obtenidas sean 3, la animación SHALL incluir una
celebración visual adicional (confeti) al completarse.

#### Scenario: Nivel superado con 2 estrellas

- **WHEN** se cierra un intento con `superado = true` y
  `estrellas_obtenidas = 2`
- **THEN** el resumen muestra el mensaje de celebración, el puntaje total,
  2 estrellas que se rellenan una a una sin confeti, y el botón
  "Continuar"

#### Scenario: Nivel superado con 3 estrellas

- **WHEN** se cierra un intento con `superado = true` y
  `estrellas_obtenidas = 3`
- **THEN** las 3 estrellas se rellenan una a una y, al completarse la
  tercera, se muestra la celebración visual adicional

#### Scenario: Continuar vuelve al camino

- **WHEN** el jugador pulsa "Continuar" en el resumen superado
- **THEN** la app vuelve al camino de niveles

### Requirement: Aviso de récord personal

El resumen en estado superado SHALL mostrar un aviso de "nuevo récord
personal" cuando el intento cerrado tenga un `mejor_puntaje_anterior` del
jugador para ese nivel y el `puntaje_total` del intento lo supere. El
resumen SHALL omitir el aviso cuando no exista un resultado anterior del
jugador en ese nivel, o cuando el puntaje del intento no mejore el
anterior.

#### Scenario: El puntaje mejora el mejor anterior

- **WHEN** el intento cerrado tiene `puntaje_total = 2140` y el jugador
  tenía `mejor_puntaje_anterior = 1820` para ese nivel
- **THEN** el resumen muestra el aviso de nuevo récord personal con la
  diferencia respecto al anterior

#### Scenario: Primer intento superado del nivel

- **WHEN** el intento cerrado no tiene un resultado anterior del jugador
  para ese nivel (nunca lo había superado ni intentado)
- **THEN** el resumen no muestra el aviso de récord personal

#### Scenario: El puntaje empata o no mejora el anterior

- **WHEN** el `puntaje_total` del intento es igual o menor que
  `mejor_puntaje_anterior`
- **THEN** el resumen no muestra el aviso de récord personal

### Requirement: Resumen en estado no superado

Cuando el intento cerrado quede `superado = false`, el resumen SHALL
mostrar: un mensaje de ánimo en tono positivo (no de fracaso), el puntaje
total del intento y cuánto le faltó para alcanzar el
`puntaje_minimo_superar` del nivel con una indicación visual de progreso
hacia ese mínimo, sus estrellas vacías, un botón "Reintentar" que arranque
un intento nuevo desde el primer desafío del mismo nivel, y un enlace
secundario "Volver al camino" que salga sin reintentar.

#### Scenario: Puntaje por debajo del mínimo

- **WHEN** se cierra un intento con `superado = false`, `puntaje_total =
  1350` y `puntaje_minimo_superar = 1500`
- **THEN** el resumen muestra el mensaje de ánimo, el puntaje total, que
  faltaron 150 puntos para el mínimo, y las estrellas vacías

#### Scenario: Reintentar arranca un intento nuevo

- **WHEN** el jugador pulsa "Reintentar" en el resumen no superado
- **THEN** la app arranca un intento nuevo del mismo nivel y muestra la
  pista de su primer desafío, sin pasar por el camino de niveles

#### Scenario: Volver al camino sin reintentar

- **WHEN** el jugador pulsa "Volver al camino" en el resumen no superado
- **THEN** la app vuelve al camino de niveles sin arrancar ningún intento
  nuevo
