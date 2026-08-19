## MODIFIED Requirements

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
la mitad y la zona crítica, y en rojo dentro de la zona crítica. Al
avanzar a un desafío nuevo, la cuenta atrás SHALL reiniciarse a los
segundos completos efectivos de la parada.

El tiempo restante SHALL derivarse del instante de fin del desafío
—calculado una vez, al volverse el actual, como el momento en que arrancó
más los segundos efectivos de la parada— y no de acumular avisos
periódicos. El relleno de la barra SHALL actualizarse en cada fotograma,
de modo que cambie también entre un segundo y el siguiente, mientras que la
etiqueta SHALL seguir mostrando segundos enteros. Cuando dejen de
entregarse fotogramas (la app pasa a segundo plano) y vuelvan a entregarse,
el tiempo restante SHALL corresponder al tiempo real transcurrido, no al
número de fotogramas o avisos perdidos.

El desafío SHALL considerarse en **zona crítica** de tiempo cuando quede
menos de una quinta parte de los segundos efectivos de la parada o menos de
5 segundos, lo que ocurra antes. La barra y el marco de aviso periférico
SHALL usar esta misma condición, para que no haya dos umbrales rojos
distintos.

Nada de esto cambia el cálculo del tiempo transcurrido ni del bonus por
rapidez, que siguen siendo del servidor: el reloj del cliente es
presentación.

#### Scenario: La cuenta atrás arranca con el desafío
- **WHEN** se muestra el primer desafío de un intento en una parada cuyo
  `segundos_por_desafio` efectivo es 60
- **THEN** la barra muestra "1:00" en teal y llama a
  `marcar_desafio_mostrado` para ese desafío

#### Scenario: La cuenta atrás cambia de color al bajar el tiempo
- **WHEN** quedan menos de la mitad de los segundos efectivos de la parada
- **THEN** la barra pasa a ámbar

#### Scenario: La cuenta atrás se pone roja cerca del final
- **WHEN** el desafío entra en zona crítica de tiempo
- **THEN** la barra pasa a rojo

#### Scenario: Zona crítica en una dificultad de pocos segundos
- **WHEN** una parada tiene 10 segundos efectivos por desafío y quedan 4
- **THEN** la barra está en rojo, aunque quede más de una quinta parte del
  tiempo, porque el suelo de 5 segundos manda

#### Scenario: La barra avanza entre un segundo y el siguiente
- **WHEN** pasa medio segundo desde el último segundo entero
- **THEN** el relleno de la barra ha cambiado respecto al del segundo
  entero anterior

#### Scenario: La etiqueta no cambia dentro del mismo segundo
- **WHEN** pasa medio segundo desde el último segundo entero
- **THEN** la etiqueta sigue mostrando el mismo `m:ss`

#### Scenario: Volver de segundo plano no regala tiempo
- **WHEN** transcurren 8 segundos de reloj real sin que se entregue ningún
  fotograma y luego se entrega uno, en un desafío de 60 segundos
- **THEN** el tiempo restante es 52 segundos, no 60

#### Scenario: La cuenta atrás sigue corriendo con la pista abierta
- **WHEN** el jugador tiene el toast de pista abierto
- **THEN** la cuenta atrás sigue descontando, visible por encima del toast

#### Scenario: Avanzar a un desafío nuevo reinicia la cuenta atrás
- **WHEN** el jugador pulsa "Siguiente" desde el revelado y pasa al
  desafío siguiente
- **THEN** la cuenta atrás vuelve a mostrar los segundos completos
  efectivos de la parada y llama a `marcar_desafio_mostrado` para el nuevo
  desafío

## ADDED Requirements

### Requirement: Marco de aviso al entrar en tiempo crítico
La pantalla SHALL mostrar, mientras el desafío actual esté en zona crítica
de tiempo, un borde rojo fino pegado a los cuatro cantos de la pantalla,
por encima del mapa y por debajo del HUD. El marco SHALL aparecer con un
fundido corto al cruzar el umbral, SHALL ser incapaz de recibir toques —el
mapa y los controles que queden debajo siguen respondiendo con normalidad—
y SHALL desaparecer al confirmar la respuesta, al agotarse el tiempo y
mientras haya un revelado en pantalla.

El movimiento del marco SHALL limitarse a un latido de opacidad lento y de
poca amplitud, nunca un parpadeo, y SHALL suprimirse cuando el sistema pida
reducir animaciones, dejando el marco fijo.

#### Scenario: El tiempo entra en zona crítica
- **WHEN** al desafío actual le queda menos de una quinta parte de su
  tiempo (o menos de 5 segundos)
- **THEN** aparece el marco rojo en el canto de la pantalla, a la vez que
  la barra del HUD se pone roja

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
