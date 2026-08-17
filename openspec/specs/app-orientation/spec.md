# app-orientation Specification

## Purpose
TBD - created by archiving change int-102-camara-vertical-zoom. Update Purpose after archive.
## Requirements
### Requirement: La app se presenta siempre en vertical

La app SHALL mostrarse únicamente en orientación vertical (portrait) en
todas sus pantallas y en las dos plataformas, y SHALL no rotar su interfaz
cuando el dispositivo gira.

La restricción SHALL declararse tanto en el arranque de la app como en la
configuración nativa de cada plataforma, de modo que el sistema operativo no
llegue a ofrecer el apaisado ni durante el lanzamiento, antes de que el
código Dart se ejecute.

El motivo es doble: no hay diseño para apaisado en ninguna pantalla, y la
cámara del mapa garantiza que el mundo cubra la altura del área visible —una
garantía que se vuelve inestable si la altura y el ancho intercambian sus
papeles a mitad de partida.

#### Scenario: Girar el dispositivo durante la partida

- **WHEN** el jugador gira el dispositivo a apaisado con la pantalla de juego
  abierta
- **THEN** la interfaz se mantiene en vertical y ni el encuadre del mapa ni
  el pin colocado cambian

#### Scenario: Orientación declarada en las dos plataformas

- **WHEN** se inspecciona la configuración nativa de iOS y de Android
- **THEN** ninguna de las dos declara orientaciones apaisadas como admitidas

