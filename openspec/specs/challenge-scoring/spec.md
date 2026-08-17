# challenge-scoring Specification

## Purpose
TBD - created by archiving change int-78-calcular-distancia-puntaje. Update Purpose after archive.

## Requirements

### Requirement: Cálculo de distancia entre coordenadas
El sistema SHALL proveer una función que calcule la distancia en
kilómetros entre dos pares de coordenadas (latitud/longitud) usando la
fórmula de Haversine.

#### Scenario: Misma ubicación exacta
- **WHEN** se calcula la distancia entre dos coordenadas idénticas
- **THEN** el resultado es 0 (o un valor despreciable por redondeo de
  punto flotante)

#### Scenario: Extremos opuestos del globo
- **WHEN** se calcula la distancia entre dos coordenadas antipodales
  (extremos opuestos de la Tierra)
- **THEN** el resultado es aproximadamente la circunferencia media
  terrestre entre antípodas (~20000 km)

### Requirement: Cálculo de puntaje a partir de la distancia
El sistema SHALL traducir una distancia en kilómetros a un puntaje entero
mediante una curva exponencial con suelo, de forma que puntúe a cualquier
distancia: puntaje máximo (`MAX`) en distancia 0, decreciente de forma
exponencial según una escala de kilómetros (`k`), sin llegar nunca a 0 y sin
bajar nunca del suelo mínimo configurado (`PISO`).

#### Scenario: Distancia cero
- **WHEN** la distancia calculada es 0
- **THEN** el puntaje es exactamente el puntaje máximo configurado (`MAX`)

#### Scenario: Distancia en las antípodas
- **WHEN** la distancia calculada es la máxima posible entre dos puntos del
  globo (~20.015 km)
- **THEN** el puntaje es exactamente el suelo mínimo configurado (`PISO`)

#### Scenario: Distancia intermedia
- **WHEN** la distancia calculada está entre 0 y la distancia máxima posible
  entre dos puntos del globo
- **THEN** el puntaje decrece de forma exponencial según la distancia y
  queda estrictamente entre `PISO` y `MAX`

#### Scenario: A mayor distancia, nunca más puntaje
- **WHEN** se comparan dos distancias donde la primera es menor que la
  segunda
- **THEN** el puntaje calculado para la primera es mayor o igual que el
  calculado para la segunda

#### Scenario: El puntaje nunca baja del suelo ni sube del máximo
- **WHEN** se calcula el puntaje para cualquier distancia no negativa
- **THEN** el resultado está siempre en el rango cerrado `[PISO, MAX]`

### Requirement: RPC para registrar la respuesta de un jugador a un desafío
El sistema SHALL exponer una RPC de Supabase que reciba el intento, el
desafío y la coordenada adivinada por el jugador, calcule distancia y
puntaje en el servidor, los persista en `respuestas_desafio` y devuelva,
junto con la respuesta registrada, el revelado del desafío que se acaba de
responder: su coordenada real, el nombre del lugar y el puntaje máximo
alcanzable.

El revelado SHALL entregarse únicamente como resultado de registrar la
jugada. La RPC SHALL no ofrecer ninguna vía para consultar la coordenada
real de un desafío sin responderlo, y el resto de superficies de lectura
(`desafios`, `desafios_para_jugar`, `iniciar_intento_nivel`) SHALL seguir
sin exponerla.

#### Scenario: Un jugador responde a un desafío de su propio intento
- **WHEN** un usuario autenticado llama a la RPC con un `intento_id` que le
  pertenece, un `desafio_id` válido y una coordenada adivinada
- **THEN** se inserta una fila en `respuestas_desafio` con la distancia y
  el puntaje calculados por el servidor
- **AND** la respuesta de la RPC incluye esa distancia y ese puntaje

#### Scenario: La respuesta revela la ubicación del desafío respondido
- **WHEN** un usuario autenticado registra su respuesta a un desafío
- **THEN** la respuesta de la RPC incluye `lat_real`, `lng_real` y
  `nombre_lugar` de ese desafío, más el puntaje máximo que se podía
  conseguir

#### Scenario: Un jugador intenta responder a un intento ajeno
- **WHEN** un usuario autenticado llama a la RPC con un `intento_id` que no
  le pertenece
- **THEN** la llamada se rechaza, no se inserta ninguna fila y no se revela
  ninguna coordenada real

#### Scenario: Un jugador intenta volver a responder el mismo desafío del intento
- **WHEN** un usuario autenticado llama a la RPC con un `intento_id` y un
  `desafio_id` para los que ya hay respuesta registrada
- **THEN** la llamada se rechaza sin registrar una segunda respuesta

#### Scenario: La ubicación real sigue oculta fuera de la jugada
- **WHEN** un jugador (incluida una sesión anónima) intenta leer la
  coordenada real de un desafío por cualquier otra vía —`select` sobre
  `desafios`, `desafios_para_jugar` o la respuesta de
  `iniciar_intento_nivel`—
- **THEN** no la obtiene por ninguna de ellas

### Requirement: Persistencia de distancia y puntaje siempre calculados por el servidor
Toda fila insertada en `respuestas_desafio`, sin importar la vía de
inserción, SHALL tener `distancia_km` y `puntos` recalculados por el
servidor a partir de `lat_adivinada`/`lng_adivinada` y las coordenadas
reales del desafío referenciado, descartando cualquier valor recibido en
el `insert` para esas dos columnas.

#### Scenario: Insert directo con valores manipulados
- **WHEN** se inserta una fila en `respuestas_desafio` indicando un
  `distancia_km`/`puntos` arbitrario junto con `lat_adivinada`/
  `lng_adivinada` válidas
- **THEN** la fila queda guardada con `distancia_km`/`puntos` calculados
  por el servidor, no con los valores recibidos en el `insert`
