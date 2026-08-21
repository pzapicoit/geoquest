## MODIFIED Requirements

### Requirement: Overlay de radio en el mapa

Al consumir un comodín `km1000` o `km500`, el mapa SHALL dibujar un círculo del radio correspondiente centrado en el centro que devuelve el servidor —que acota al objetivo sin situarlo en el centro—, y SHALL animar la cámara para encuadrar ese círculo entero. La app SHALL tratar ese centro como un dato opaco: no SHALL asumir que coincide con la posición del objetivo ni derivar de él ninguna pista adicional.

#### Scenario: Se consume un comodín de radio

- **WHEN** el jugador consume `km1000` o `km500` con éxito
- **THEN** el mapa dibuja un círculo del radio correspondiente centrado en el centro recibido del servidor, visible mientras el jugador sigue en la fase de adivinar de ese desafío
- **AND** la cámara se anima hacia un encuadre que deja el círculo completo visible

#### Scenario: El jugador confirma mientras la cámara todavía se está acercando

- **WHEN** el jugador confirma su respuesta antes de que termine la animación de acercamiento del comodín de radio
- **THEN** esa animación se detiene y la cámara pasa a estar gobernada por la coreografía del revelado, sin que ambas compitan por el mismo encuadre
