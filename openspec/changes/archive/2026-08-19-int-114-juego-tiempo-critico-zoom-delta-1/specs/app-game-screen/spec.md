## MODIFIED Requirements

### Requirement: Marco de aviso al entrar en tiempo crítico
La pantalla SHALL mostrar, mientras el desafío actual esté en zona crítica
de tiempo, un borde rojo fino siguiendo el contorno de la pantalla, por
encima del mapa y por debajo del HUD. El borde SHALL tener las esquinas
redondeadas y SHALL quedar metido unos píxeles hacia dentro del área
visible, de modo que ningún tramo suyo caiga fuera de la esquina
redondeada del dispositivo y quede cortado, sea cual sea el radio de esa
esquina. El grosor SHALL ser el suficiente para verse con el mapa a
pantalla completa sin dejar de leerse como un borde.

El marco SHALL aparecer con un fundido corto al cruzar el umbral, SHALL ser
incapaz de recibir toques —el mapa y los controles que queden debajo siguen
respondiendo con normalidad— y SHALL desaparecer al confirmar la respuesta,
al agotarse el tiempo y mientras haya un revelado en pantalla.

El movimiento del marco SHALL limitarse a un latido de opacidad lento y de
poca amplitud, nunca un parpadeo, y SHALL suprimirse cuando el sistema pida
reducir animaciones, dejando el marco fijo.

#### Scenario: El tiempo entra en zona crítica
- **WHEN** al desafío actual le queda menos de una quinta parte de su
  tiempo (o menos de 5 segundos)
- **THEN** aparece el marco rojo en el canto de la pantalla, a la vez que
  la barra del HUD se pone roja

#### Scenario: El marco no se corta en las esquinas del dispositivo
- **WHEN** hay marco en pantalla
- **THEN** su contorno es redondeado y no llega a tocar el borde del área
  visible, así que cabe entero dentro de una pantalla con esquinas
  redondeadas

#### Scenario: Con tiempo de sobra no hay marco
- **WHEN** al desafío actual le queda más de una quinta parte de su tiempo
  y más de 5 segundos
- **THEN** no hay ningún marco en pantalla

#### Scenario: El marco no se come los toques
- **WHEN** el desafío está en zona crítica y el jugador toca el mapa en un
  punto que cae sobre el marco
- **THEN** el mapa coloca el pin en ese punto igual que sin marco

#### Scenario: Confirmar apaga el marco
- **WHEN** el desafío está en zona crítica y el jugador confirma su
  respuesta
- **THEN** el marco desaparece y no vuelve durante el revelado

#### Scenario: Agotarse el tiempo apaga el marco
- **WHEN** la cuenta atrás del desafío llega a 0
- **THEN** el marco desaparece junto con la barra de cuenta atrás

#### Scenario: El desafío siguiente arranca sin marco
- **WHEN** el jugador avanza desde el revelado a un desafío nuevo
- **THEN** la cuenta atrás vuelve a los segundos completos y no hay marco
  hasta que ese desafío entre en zona crítica

#### Scenario: Sistema con animaciones reducidas
- **WHEN** el sistema pide reducir animaciones y el desafío entra en zona
  crítica
- **THEN** el marco se muestra fijo, sin latido de opacidad
