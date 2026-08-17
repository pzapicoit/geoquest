## MODIFIED Requirements

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
