## MODIFIED Requirements

### Requirement: Paso 2 — propuestas revisables candidato a candidato

Tras pedir la propuesta, la pantalla SHALL mostrar los candidatos devueltos en
una tabla con, por fila: la descripción del lugar generada por la IA, el nombre
del lugar, su ciudad y su país, sus coordenadas y su dificultad. Cada fila SHALL
poder marcarse y desmarcarse, y todas SHALL empezar marcadas. La pantalla SHALL
ofrecer "marcar/desmarcar todas", pedir otra tanda y descartar la tanda actual.

La ciudad SHALL ser visible en esta revisión, no solo persistirse en silencio:
es lo que el jugador leerá al revelar la respuesta, así que una ciudad
equivocada tiene que poderse detectar antes de gastar la ilustración. Un
candidato sin ciudad SHALL mostrarse como tal, sin bloquear su selección.

#### Scenario: Llegan los candidatos

- **WHEN** la IA devuelve 10 candidatos para la tanda pedida
- **THEN** la tabla muestra 10 filas, todas marcadas, con lugar, ciudad, país,
  coordenadas y dificultad de cada una

#### Scenario: Un candidato sin ciudad se revisa igual

- **WHEN** uno de los candidatos devueltos llega sin ciudad
- **THEN** su fila lo indica y sigue marcable, seleccionable e ilustrable como
  cualquier otra

#### Scenario: El admin descarta un candidato

- **WHEN** un admin desmarca la fila de un candidato
- **THEN** esa fila deja de contarse entre las seleccionadas y no se ilustrará

#### Scenario: Desmarcar todas deshabilita continuar

- **WHEN** un admin desmarca todos los candidatos
- **THEN** la acción de generar imágenes queda deshabilitada y la pantalla pide
  marcar al menos uno

#### Scenario: Descartar la tanda

- **WHEN** un admin descarta la tanda
- **THEN** la pantalla vuelve al paso 1 sin candidatos ni imágenes, sin haber
  guardado nada

#### Scenario: Mientras se piden las propuestas

- **WHEN** la petición de candidatos está en curso
- **THEN** la pantalla muestra que está redactando la tanda y no permite lanzar
  otra en paralelo

### Requirement: Guardado del lote en el banco

Al guardar, la pantalla SHALL crear una fila en `desafios` por cada candidato
marcado **que tenga imagen lista**, con `tipo = 'imagen'`, la temática y
dificultad elegidas, el nombre del lugar, su ciudad y su país, sus coordenadas, y
la imagen subida a `challenge-media` bajo `imagen/{desafio_id}.{extension}`. El
estado `activo` de las filas creadas SHALL venir del toggle "Publicar activas" de
la barra de guardado. Al terminar, la pantalla SHALL confirmar cuántas preguntas
se han creado y en qué estado, y ofrecer volver al banco.

La ciudad y el país de un candidato sin ese dato SHALL persistirse como `NULL`,
no como cadena vacía: la app distingue una cosa de la otra para decidir qué
rotula el revelado, y el comodín de país para decidir si está disponible.

#### Scenario: Se guarda un lote completo

- **WHEN** un admin guarda 8 candidatos con sus 8 imágenes listas
- **THEN** el banco tiene 8 desafíos nuevos de tipo `imagen` de esa temática y
  dificultad, cada uno con su imagen en `imagen/{id}.{extension}` y con la
  ciudad y el país que traía su candidato

#### Scenario: Se guarda un candidato sin ciudad

- **WHEN** un admin guarda un candidato que llegó sin ciudad
- **THEN** la fila creada en `desafios` tiene `ciudad` a `NULL`, y no una cadena
  vacía

#### Scenario: Guardar con "Publicar activas" desactivado

- **WHEN** un admin desactiva "Publicar activas" y guarda el lote
- **THEN** las filas creadas quedan con `activo = false` y la confirmación
  indica que se han guardado como inactivas

#### Scenario: No se guarda lo que no tiene imagen

- **WHEN** un candidato marcado sigue con su imagen fallida al guardar
- **THEN** ese candidato no genera fila en `desafios` y la pantalla lo indica

#### Scenario: No se puede guardar mientras quedan imágenes en curso

- **WHEN** todavía hay ilustraciones generándose
- **THEN** la acción de guardar queda deshabilitada e indica que espera a que
  terminen

#### Scenario: Falla el guardado de una fila

- **WHEN** la subida de la imagen o la inserción de una fila falla
- **THEN** la pantalla informa de qué candidatos no se pudieron guardar y
  mantiene el lote en pantalla para reintentar, sin perder las imágenes ya
  generadas
