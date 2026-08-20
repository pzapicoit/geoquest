## MODIFIED Requirements

### Requirement: `proponer-lugares` devuelve candidatos estructurados

La función `proponer-lugares` SHALL aceptar la temática, la dificultad, la
cantidad pedida, las indicaciones extra opcionales del admin y los desafíos que
ya existen en esa temática con su nombre y sus coordenadas, y SHALL devolver una
lista de candidatos con nombre, coordenadas reales (latitud entre -90 y 90,
longitud entre -180 y 180), la ciudad y el país del objetivo, y una descripción
que no nombre la respuesta. El prompt enviado a OpenAI SHALL construirse dentro
de la función; el invocador MUST NOT poder sustituirlo.

La ciudad y el país SHALL corresponder a las coordenadas propuestas, y SHALL
poder venir vacíos cuando el objetivo no tenga ciudad o país reales —un punto en
aguas internacionales, un paraje despoblado—, en vez de rellenarse con la
localidad más cercana. Un candidato sin ciudad SHALL seguir siendo válido: la
ciudad no es un campo cuya ausencia lo descarte.

Los desafíos existentes SHALL cumplir dos funciones: excluirse de la propuesta y
**definir qué cuenta como respuesta en esa temática**. El tipo de respuesta
MUST NOT fijarse en el prompt, porque varía por temática: hay temáticas que
responden países con las coordenadas de su capital, otras ciudades, otras títulos
de obra con las coordenadas del lugar que les corresponde, y otras lugares
concretos.

La descripción SHALL seguir sin nombrar la respuesta, ni su país, ni su ciudad,
ni su gentilicio: que la función devuelva ahora ciudad y país como datos
estructurados MUST NOT relajar esa regla, porque la descripción es la pista que
lee el jugador y esos datos son parte de lo que tiene que deducir.

Las indicaciones del administrador SHALL tener prioridad sobre ese criterio
deducido a la hora de decidir qué proponer, y MUST NOT alterar las reglas de
formato de la respuesta ni la de no repetir lo ya existente.

#### Scenario: Petición válida

- **WHEN** un admin pide 10 lugares de la temática "Monumentos" con dificultad
  "Intermedio"
- **THEN** la función devuelve hasta 10 candidatos, cada uno con nombre,
  latitud, longitud, ciudad, país y descripción

#### Scenario: La ciudad y el país corresponden a las coordenadas

- **WHEN** la función propone un candidato con las coordenadas del Coliseo
- **THEN** ese candidato viene con ciudad "Roma" y país "Italia", no con la
  ciudad o el país de otro candidato de la tanda

#### Scenario: Un objetivo sin ciudad real

- **WHEN** la función propone un candidato cuyas coordenadas caen en aguas
  internacionales o en un paraje despoblado
- **THEN** ese candidato llega con la ciudad vacía y se devuelve igualmente,
  en vez de descartarse o de traer la localidad más cercana

#### Scenario: La descripción sigue sin delatar la ciudad

- **WHEN** la función devuelve un candidato con ciudad "Roma"
- **THEN** su descripción no nombra Roma, ni Italia, ni el gentilicio de
  ninguna de las dos

#### Scenario: El tipo de respuesta lo marca el banco de la temática

- **WHEN** se piden candidatos para una temática cuyos desafíos existentes son
  países con las coordenadas de su capital
- **THEN** los candidatos devueltos son también países con coordenadas de capital,
  y no lugares concretos dentro de esas ciudades

#### Scenario: Las indicaciones del administrador mandan sobre el tipo

- **WHEN** el administrador pide explícitamente un tipo de respuesta distinto al
  que se deduce del banco
- **THEN** la propuesta sigue lo que pide el administrador

#### Scenario: Se respetan las exclusiones

- **WHEN** la petición incluye "Torre Eiffel" en la lista de exclusión
- **THEN** el prompt enviado a OpenAI pide explícitamente evitar ese lugar

#### Scenario: Las indicaciones extra se incorporan

- **WHEN** el admin añade la indicación "solo hemisferio sur"
- **THEN** esa indicación llega a OpenAI como parte de la petición, sin
  reemplazar las instrucciones de formato de la función

#### Scenario: Coordenadas fuera de rango

- **WHEN** OpenAI devuelve un candidato con latitud 120
- **THEN** la función descarta ese candidato en vez de devolverlo

#### Scenario: Respuesta no interpretable

- **WHEN** la respuesta de OpenAI no encaja con el formato esperado
- **THEN** la función responde con el código de error `respuesta_invalida`
