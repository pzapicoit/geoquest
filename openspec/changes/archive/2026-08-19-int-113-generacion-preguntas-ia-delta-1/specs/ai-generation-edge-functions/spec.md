## ADDED Requirements

### Requirement: `generar-imagen-lugar` distingue estilo de temática e indicaciones de tanda

La función SHALL aceptar, además de las indicaciones de la tanda, el estilo de
ilustración propio de la temática, y SHALL tratarlos como dos cosas distintas en
el prompt: el estilo de la temática decide **qué y cómo se dibuja** en esa
temática, y las indicaciones de la tanda lo matizan. Ambos SHALL ser opcionales.

#### Scenario: Llega el estilo de la temática

- **WHEN** se invoca con un estilo de temática que pide la bandera sobre fondo
  neutro
- **THEN** la ilustración devuelta muestra la bandera sobre fondo neutro, sin
  escena alrededor

#### Scenario: Llegan los dos

- **WHEN** se invoca con estilo de temática y con indicaciones de tanda
- **THEN** el prompt incorpora los dos, y el estilo de la temática prevalece
  sobre las reglas genéricas de la función

#### Scenario: No llega ninguno

- **WHEN** se invoca sin estilo de temática ni indicaciones
- **THEN** la función se comporta como antes de este delta
