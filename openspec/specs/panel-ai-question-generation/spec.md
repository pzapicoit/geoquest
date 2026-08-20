# panel-ai-question-generation Specification

## Purpose
Generación asistida por IA de preguntas del banco desde el panel: el wizard que
propone lugares reales para una temática y dificultad, los deja revisar candidato a
candidato, ilustra los aprobados y guarda el lote en `desafios`.

## Requirements

### Requirement: Pantalla de generación con IA accesible desde Preguntas

El panel SHALL exponer la generación de preguntas con IA en la ruta
`/preguntas/generar-ia`, protegida por la misma sesión que el resto del panel y
dentro del layout común. El listado de preguntas SHALL ofrecer un acceso
directo a esa ruta.

#### Scenario: Un admin autenticado abre la pantalla

- **WHEN** un admin con sesión activa navega a `/preguntas/generar-ia`
- **THEN** el panel muestra el wizard de generación dentro del layout del panel

#### Scenario: Un visitante sin sesión intenta abrir la pantalla

- **WHEN** alguien sin sesión navega a `/preguntas/generar-ia`
- **THEN** el panel lo redirige al login, igual que con el resto de rutas

#### Scenario: Acceso desde el listado de preguntas

- **WHEN** un admin hace click en "Generar con IA" en el listado de preguntas
- **THEN** el panel navega a `/preguntas/generar-ia`

### Requirement: Indicador de los tres pasos del wizard

La pantalla SHALL mostrar un indicador con los tres pasos —configurar, revisar
propuestas, ilustrar y guardar— señalando el paso actual y marcando como
completados los ya superados.

#### Scenario: Estado inicial del indicador

- **WHEN** la pantalla se abre sin haber generado nada
- **THEN** el indicador marca el paso 1 como actual y los pasos 2 y 3 como
  pendientes

#### Scenario: El indicador avanza con el wizard

- **WHEN** la IA ha devuelto candidatos y el admin está revisándolos
- **THEN** el indicador marca el paso 1 como completado y el paso 2 como actual

### Requirement: Paso 1 — configuración de la tanda

El paso 1 SHALL pedir temática (obligatoria, de las temáticas existentes),
dificultad (obligatoria, uno de los cinco valores del enum `dificultad`),
cantidad de preguntas (entre 3 y 20, por defecto 8) e indicaciones extra
opcionales en texto libre. Ninguna de estas acciones SHALL llamar a la IA.

#### Scenario: Se eligen temática, dificultad y cantidad

- **WHEN** un admin selecciona la temática "Monumentos", la dificultad
  "Intermedio" y sube la cantidad a 10
- **THEN** la pantalla refleja esa configuración y ofrece lanzar la propuesta,
  sin haber llamado a ninguna función de IA

#### Scenario: La cantidad no sale del rango permitido

- **WHEN** un admin intenta bajar la cantidad por debajo de 3 o subirla por
  encima de 20
- **THEN** la cantidad se queda en el límite correspondiente

#### Scenario: Las dificultades ofrecidas son las del catálogo

- **WHEN** un admin abre el paso 1
- **THEN** puede elegir entre las cinco dificultades del catálogo (Fácil,
  Normal, Intermedio, Difícil, Muy difícil) y ninguna otra

#### Scenario: No se puede lanzar sin temática

- **WHEN** no hay ninguna temática seleccionada
- **THEN** la acción de generar propuestas queda deshabilitada

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

### Requirement: La descripción generada no se persiste

La descripción textual de cada candidato SHALL usarse como contexto de revisión
y como base del prompt de la ilustración, pero MUST NOT guardarse en
`desafios`: un desafío de tipo `imagen` tiene `texto_pregunta` a `null` por
restricción del modelo de datos.

#### Scenario: Se guarda un candidato con descripción

- **WHEN** se guarda un candidato cuya descripción es "Anfiteatro romano de
  50 000 plazas"
- **THEN** la fila creada en `desafios` tiene `tipo = 'imagen'` y
  `texto_pregunta = null`

### Requirement: Las indicaciones extra guían la tanda completa

Las indicaciones extra del paso 1 SHALL guiar tanto la propuesta de lugares como
la ilustración de los candidatos aprobados, y SHALL ser las de la tanda en curso
aunque el admin edite el campo después de lanzarla.

#### Scenario: La ilustración respeta las indicaciones de la tanda

- **WHEN** el admin lanza una tanda con indicaciones sobre banderas y luego pide
  las ilustraciones
- **THEN** cada ilustración se pide con esas mismas indicaciones

#### Scenario: Editar el campo no cambia la tanda en curso

- **WHEN** el admin cambia el texto de indicaciones después de haber lanzado la
  tanda
- **THEN** las ilustraciones de esa tanda siguen usando las indicaciones con las
  que se pidieron los candidatos

### Requirement: Candidatos sin duplicar el banco ni el propio lote

La pantalla SHALL descartar los candidatos que dupliquen un desafío ya
existente de la misma temática o otro candidato del mismo lote. Dos lugares
SHALL considerarse el mismo cuando su nombre normalizado —sin acentos, sin
distinguir mayúsculas, sin espacios ni signos de puntuación redundantes—
coincida, o cuando sus coordenadas estén a 10 km o menos.

#### Scenario: La IA propone un lugar que ya está en el banco

- **WHEN** la IA propone "Torre Eiffel" y el banco de esa temática ya tiene un
  desafío llamado "torre eiffel"
- **THEN** ese candidato no llega a la tabla de revisión

#### Scenario: Mismo lugar con otro nombre

- **WHEN** la IA propone "Eiffel Tower" con coordenadas a menos de 10 km de un
  desafío ya existente de esa temática
- **THEN** ese candidato no llega a la tabla de revisión

#### Scenario: Duplicado dentro del mismo lote

- **WHEN** la IA devuelve dos candidatos que son el mismo lugar entre sí
- **THEN** solo uno de ellos llega a la tabla de revisión

#### Scenario: Un lugar cercano de otra temática no es duplicado

- **WHEN** la IA propone un lugar a menos de 10 km de un desafío que pertenece a
  **otra** temática
- **THEN** ese candidato sí llega a la tabla de revisión

### Requirement: Rondas extra cuando la deduplicación deja la tanda corta

Cuando tras deduplicar queden menos candidatos de los pedidos, la pantalla SHALL
pedir a la IA los que faltan, informándole de los lugares ya excluidos, hasta un
máximo de dos rondas adicionales. Si al agotarlas sigue faltando, SHALL entregar
los candidatos conseguidos e informar de cuántos son y por qué son menos.

#### Scenario: Una ronda extra completa la tanda

- **WHEN** se piden 10 candidatos, la primera respuesta deja 7 tras deduplicar y
  la ronda siguiente aporta 3 válidos
- **THEN** la tabla muestra 10 candidatos

#### Scenario: Se agotan las rondas sin completar

- **WHEN** se piden 10 candidatos y tras las rondas extra solo hay 6 válidos
- **THEN** la tabla muestra los 6 y la pantalla avisa de que la IA no encontró
  más lugares nuevos para esa temática y dificultad

### Requirement: Aviso de coste antes de ilustrar

Antes de lanzar la generación de imágenes, la pantalla SHALL indicar cuántas
imágenes se van a generar y su coste aproximado, y SHALL dejar claro que el paso
de propuestas de texto no genera imágenes.

#### Scenario: Resumen antes de ilustrar

- **WHEN** un admin tiene 8 candidatos marcados
- **THEN** la pantalla indica que se generarán 8 imágenes y su coste aproximado
  antes de que confirme

### Requirement: Paso 3 — una ilustración por candidato aprobado

Para cada candidato marcado, la pantalla SHALL pedir su ilustración en una
llamada independiente y mostrar una tarjeta por candidato con su estado —en
cola, generando, lista o fallida— más el progreso agregado del lote. Cada
tarjeta SHALL permitir rehacer su imagen.

#### Scenario: Progreso del lote

- **WHEN** hay 8 candidatos y 3 imágenes están listas
- **THEN** la pantalla muestra "3 / 8" y la barra de progreso al 37,5 %

#### Scenario: Una imagen lista se ve en la revisión

- **WHEN** termina la ilustración de un candidato
- **THEN** su tarjeta muestra la previsualización de la imagen generada y su
  estado pasa a lista

#### Scenario: Rehacer una imagen

- **WHEN** un admin pulsa rehacer en una tarjeta que ya tiene imagen
- **THEN** esa tarjeta vuelve a estado generando y su imagen se sustituye por la
  nueva cuando llega, sin afectar al resto

#### Scenario: Falla la imagen de un candidato

- **WHEN** la generación de la imagen de un candidato falla
- **THEN** esa tarjeta queda en estado fallida con opción de reintentar, y el
  resto del lote sigue su curso

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

### Requirement: Mensajes propios ante fallos de la IA

La pantalla SHALL traducir los fallos de las funciones de IA a mensajes en
castellano y MUST NOT mostrar el error crudo de OpenAI ni de la Edge Function.
SHALL distinguir al menos: secreto de OpenAI sin configurar, fallo o
indisponibilidad de la IA, y respuesta sin candidatos nuevos.

#### Scenario: El secreto no está configurado

- **WHEN** la función responde que falta el secreto de OpenAI
- **THEN** la pantalla explica que la clave de OpenAI no está configurada en el
  proyecto de Supabase y que no se ha generado nada

#### Scenario: La IA falla o no responde

- **WHEN** la llamada a la función falla, agota su tiempo o devuelve un error de
  OpenAI
- **THEN** la pantalla muestra un mensaje propio invitando a reintentar, sin
  volcar el error técnico

#### Scenario: La IA no devuelve nada usable

- **WHEN** la función responde sin candidatos
- **THEN** la pantalla lo explica como que la IA no encontró lugares nuevos para
  esa temática y dificultad

### Requirement: El estilo de la temática se aplica a todas sus ilustraciones

Al ilustrar los candidatos aprobados, la pantalla SHALL enviar el
`prompt_imagen` de la temática elegida junto con cada petición de imagen, sin
que el admin tenga que reescribirlo. Cuando la temática no tenga prompt, SHALL
enviarse vacío y el comportamiento SHALL ser el de antes de este delta.

Las indicaciones extra de la tanda SHALL seguir enviándose y SHALL convivir con
el prompt de la temática: el de la temática es el estilo permanente, las
indicaciones son el matiz de esa tanda.

#### Scenario: Se ilustra una temática con estilo propio

- **WHEN** se generan las imágenes de una tanda de una temática cuyo
  `prompt_imagen` describe su estilo
- **THEN** cada petición de imagen incluye ese estilo

#### Scenario: Se ilustra una temática sin estilo propio

- **WHEN** la temática elegida no tiene `prompt_imagen`
- **THEN** las peticiones de imagen se hacen sin estilo de temática, y las
  indicaciones extra de la tanda siguen aplicándose

#### Scenario: Conviven estilo de temática e indicaciones de la tanda

- **WHEN** la temática tiene `prompt_imagen` y además el admin escribió
  indicaciones extra
- **THEN** cada petición de imagen lleva las dos cosas, distinguidas

### Requirement: El paso 1 muestra el estilo que se va a aplicar

Al elegir una temática con `prompt_imagen`, el paso 1 SHALL mostrar ese texto en
modo lectura, para que el admin sepa con qué se van a ilustrar las preguntas
antes de gastar en imágenes. SHALL indicar también dónde se edita.

#### Scenario: La temática elegida tiene estilo

- **WHEN** el admin selecciona una temática con `prompt_imagen`
- **THEN** el paso 1 muestra ese texto como el estilo que se aplicará

#### Scenario: La temática elegida no tiene estilo

- **WHEN** el admin selecciona una temática sin `prompt_imagen`
- **THEN** el paso 1 lo indica y señala que puede definirse en la temática
