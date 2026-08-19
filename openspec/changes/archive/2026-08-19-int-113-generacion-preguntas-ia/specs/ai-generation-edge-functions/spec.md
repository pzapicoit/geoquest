## ADDED Requirements

### Requirement: La clave de OpenAI vive solo como secreto de la función

La API key de OpenAI SHALL leerse exclusivamente de la variable de entorno
`geo_open_api` de las Edge Functions. MUST NOT guardarse en la base de datos, ni
versionarse en el repositorio, ni viajar al navegador, ni existir pantalla del
panel que la pida o la muestre.

#### Scenario: La función lee la clave de su entorno

- **WHEN** una Edge Function necesita llamar a OpenAI
- **THEN** obtiene la clave de la variable de entorno `geo_open_api` del propio
  runtime

#### Scenario: El secreto no está configurado

- **WHEN** se invoca una función y `geo_open_api` no está definida
- **THEN** la función responde con el código de error `secreto_no_configurado` y
  sin llamar a OpenAI

#### Scenario: Ninguna respuesta filtra la clave

- **WHEN** una llamada a OpenAI falla por credencial inválida
- **THEN** la respuesta de la función describe el fallo sin incluir la clave ni
  el cuerpo crudo del error de OpenAI

### Requirement: Solo un administrador puede invocar las funciones

Ambas funciones SHALL exigir un JWT válido y comprobar que el invocador tiene
`profiles.role = 'admin'`. Cualquier otro invocador —anónimo, sin sesión, o
jugador autenticado— SHALL ser rechazado sin llegar a llamar a OpenAI.

#### Scenario: Invoca un admin

- **WHEN** un usuario con `profiles.role = 'admin'` invoca la función
- **THEN** la función procede con la generación

#### Scenario: Invoca un jugador

- **WHEN** un usuario autenticado con `profiles.role = 'jugador'` (incluida una
  sesión anónima) invoca la función
- **THEN** la función responde `no_autorizado` y no llama a OpenAI

#### Scenario: Invoca alguien sin sesión

- **WHEN** se invoca la función sin JWT o con un JWT inválido
- **THEN** la función rechaza la petición y no llama a OpenAI

### Requirement: `proponer-lugares` devuelve candidatos estructurados

La función `proponer-lugares` SHALL aceptar la temática, la dificultad, la
cantidad pedida, las indicaciones extra opcionales del admin y la lista de
lugares a excluir, y SHALL devolver una lista de candidatos con nombre del
lugar, coordenadas reales (latitud entre -90 y 90, longitud entre -180 y 180) y
una descripción del lugar que no lo nombre. El prompt enviado a OpenAI SHALL
construirse dentro de la función; el invocador MUST NOT poder sustituirlo.

#### Scenario: Petición válida

- **WHEN** un admin pide 10 lugares de la temática "Monumentos" con dificultad
  "Intermedio"
- **THEN** la función devuelve hasta 10 candidatos, cada uno con nombre,
  latitud, longitud y descripción

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

### Requirement: `generar-imagen-lugar` ilustra un solo lugar por invocación

La función `generar-imagen-lugar` SHALL generar la ilustración de **un** lugar
por invocación, en estilo ilustración 3D tipo Pixar, sin texto ni marcas de
agua, y SHALL devolver la imagen en línea junto con su tipo MIME, en un formato
aceptado por el bucket `challenge-media`.

#### Scenario: Se ilustra un lugar

- **WHEN** un admin pide la ilustración del lugar "Coliseo, Roma"
- **THEN** la función devuelve una imagen y su tipo MIME, entre los aceptados por
  `challenge-media`

#### Scenario: Una invocación por imagen

- **WHEN** hay que ilustrar 8 candidatos
- **THEN** se producen 8 invocaciones independientes, de modo que el fallo o la
  duración de una no arrastra a las demás

#### Scenario: Falla la generación de la imagen

- **WHEN** OpenAI devuelve error al generar la imagen
- **THEN** la función responde con el código de error `openai_error` y sin
  imagen

### Requirement: Modelos configurables por entorno

Los modelos de texto e imagen SHALL leerse de variables de entorno de la
función, con un valor por defecto documentado, de forma que cambiarlos no exija
modificar el código.

#### Scenario: Se cambia el modelo sin tocar código

- **WHEN** se define la variable de entorno del modelo de texto con otro modelo
  de OpenAI
- **THEN** la siguiente invocación usa ese modelo, sin redeploy de código

#### Scenario: Sin variable definida

- **WHEN** las variables de modelo no están definidas
- **THEN** la función usa los modelos por defecto documentados en
  `backend/README.md`

### Requirement: Errores con código propio

Las respuestas de error de ambas funciones SHALL incluir un código estable de un
conjunto cerrado —`no_autorizado`, `secreto_no_configurado`, `peticion_invalida`,
`respuesta_invalida`, `openai_error`— para que el panel pueda traducirlos a
mensajes propios.

#### Scenario: El panel distingue el motivo

- **WHEN** la función falla porque falta el secreto
- **THEN** la respuesta incluye el código `secreto_no_configurado`, distinguible
  de un fallo de OpenAI

#### Scenario: Petición mal formada

- **WHEN** se invoca `proponer-lugares` sin temática o con una cantidad fuera de
  rango
- **THEN** la respuesta incluye el código `peticion_invalida`

### Requirement: Las funciones acotan su tiempo de espera

Cada función SHALL acotar el tiempo de espera de su llamada a OpenAI y devolver
un error de su conjunto cerrado al agotarlo, en vez de quedar colgada hasta el
límite del runtime.

#### Scenario: OpenAI no responde a tiempo

- **WHEN** la llamada a OpenAI supera el tiempo de espera configurado
- **THEN** la función corta la espera y responde `openai_error`

### Requirement: Las funciones se versionan en el repositorio

El código de las Edge Functions SHALL vivir bajo `backend/supabase/functions/` y
estar declarado en `backend/supabase/config.toml`, de modo que un clon limpio
pueda desplegarlas sin pasos manuales en el dashboard.

#### Scenario: Un clon limpio despliega las funciones

- **WHEN** un desarrollador clona el repo, se autentica y sigue el arranque
  documentado
- **THEN** puede desplegar ambas funciones desde el repositorio, y solo el
  secreto se configura aparte
