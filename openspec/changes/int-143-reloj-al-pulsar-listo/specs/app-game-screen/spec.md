## MODIFIED Requirements

### Requirement: Cuenta atrás visible durante la fase de adivinar
La pantalla SHALL mostrar, en la capa fija del HUD, una barra de cuenta
atrás con etiqueta `m:ss` para el desafío actual, inicializada al
`segundos_por_desafio` efectivo de la parada en curso (override propio, o
el de `dificultad_defaults` para su dificultad si no tiene override). La
barra SHALL arrancar, y marcar el desafío como mostrado (RPC
`marcar_desafio_mostrado`), en el instante en que el jugador cierra por
primera vez la pista de ese desafío —al pulsar "Listo, voy a adivinar", la X
o el fondo— y no al mostrarse la pista. Mientras la pista de un desafío no se
ha cerrado nunca, la barra SHALL mostrarse llena y quieta. La pista SHALL
tener un tope de lectura de 20 segundos, visible en la propia tarjeta: al
agotarse, la pista se cierra sola y arranca la cuenta atrás, como si el
jugador hubiera pulsado "Listo". Con el lector de pantalla activo, la pista
SHALL NOT tener tope de lectura. Si el jugador vuelve a abrir la pista ("Ver
la pista") con la cuenta atrás ya en marcha, la cuenta atrás SHALL seguir
corriendo, igual que el resto del HUD. La barra SHALL
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

#### Scenario: La cuenta atrás espera a que se cierre la pista
- **WHEN** se muestra el primer desafío de un intento en una parada cuyo
  `segundos_por_desafio` efectivo es 60 y el jugador lleva 10 segundos
  leyendo la pista
- **THEN** la barra sigue mostrando "1:00" y todavía no se ha llamado a
  `marcar_desafio_mostrado`

#### Scenario: La cuenta atrás arranca al pulsar "Listo"
- **WHEN** el jugador pulsa "Listo, voy a adivinar" en la pista
- **THEN** la barra arranca desde "1:00" en teal y se llama a
  `marcar_desafio_mostrado` para ese desafío

#### Scenario: La pista se cierra sola al agotar su tope de lectura
- **WHEN** el jugador deja la pista abierta 20 segundos sin cerrarla
- **THEN** la pista se cierra, la barra arranca desde los segundos completos
  y se llama a `marcar_desafio_mostrado`

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

#### Scenario: Sin tope de lectura con lector de pantalla
- **WHEN** el jugador usa un lector de pantalla y deja la pista abierta más de
  20 segundos
- **THEN** la pista sigue abierta y la cuenta atrás sigue llena y quieta

#### Scenario: Reabrir la pista no para la cuenta atrás
- **WHEN** el jugador vuelve a abrir la pista con "Ver la pista" después de
  haberla cerrado
- **THEN** la cuenta atrás sigue descontando, visible por encima del toast,
  y no se vuelve a llamar a `marcar_desafio_mostrado`

#### Scenario: Avanzar a un desafío nuevo reinicia la cuenta atrás
- **WHEN** el jugador pulsa "Siguiente" desde el revelado y pasa al
  desafío siguiente
- **THEN** la cuenta atrás vuelve a mostrar los segundos completos
  efectivos de la parada, quieta hasta que el jugador cierre la pista del
  nuevo desafío, y solo entonces llama a `marcar_desafio_mostrado` para él
