## MODIFIED Requirements

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
