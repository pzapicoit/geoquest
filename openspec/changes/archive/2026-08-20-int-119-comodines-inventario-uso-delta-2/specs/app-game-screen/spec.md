## MODIFIED Requirements

### Requirement: Overlay de radio en el mapa

Al consumir un comodín `km1000` o `km500`, el mapa SHALL dibujar un círculo centrado en la posición real del objetivo con el radio correspondiente, y SHALL animar la cámara para encuadrar ese círculo entero.

#### Scenario: Se consume un comodín de radio

- **WHEN** el jugador consume `km1000` o `km500` con éxito
- **THEN** el mapa dibuja un círculo del radio correspondiente centrado en la posición real del objetivo, visible mientras el jugador sigue en la fase de adivinar de ese desafío
- **AND** la cámara se anima hacia un encuadre que deja el círculo completo visible

#### Scenario: El jugador confirma mientras la cámara todavía se está acercando

- **WHEN** el jugador confirma su respuesta antes de que termine la animación de acercamiento del comodín de radio
- **THEN** esa animación se detiene y la cámara pasa a estar gobernada por la coreografía del revelado, sin que ambas compitan por el mismo encuadre
