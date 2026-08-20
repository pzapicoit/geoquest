# panel-questions-form Specification

## Purpose
TBD - created by syncing change int-83-panel-preguntas-crear-editar. Update Purpose after archive.

## Requirements

### Requirement: Selector de tipo excluyente
El formulario SHALL ofrecer un selector excluyente entre Imagen, Pregunta
de texto y Vídeo, mostrando únicamente el campo de contenido
correspondiente al tipo elegido.

#### Scenario: Cambiar de tipo oculta el campo anterior
- **WHEN** un admin tiene seleccionado "Imagen" con un archivo cargado y
  cambia el tipo a "Pregunta de texto"
- **THEN** el formulario oculta el campo de imagen y muestra el textarea de
  pregunta de texto

### Requirement: Contenido de tipo imagen con previsualización
Cuando el tipo sea Imagen, el formulario SHALL permitir subir un archivo
`image/jpeg`, `image/png` o `image/webp` de hasta 50 MiB y mostrar su
previsualización antes de guardar.

#### Scenario: Se selecciona una imagen válida
- **WHEN** un admin selecciona un archivo `image/png` de 3 MiB para el
  campo de imagen
- **THEN** el formulario muestra la previsualización de esa imagen

#### Scenario: Se selecciona un archivo de tipo o tamaño no permitido
- **WHEN** un admin selecciona un archivo que no es
  `image/jpeg`/`image/png`/`image/webp`, o que supera 50 MiB, para el campo
  de imagen
- **THEN** el formulario rechaza el archivo y muestra un mensaje de error,
  sin subirlo

### Requirement: Contenido de tipo vídeo con previsualización
Cuando el tipo sea Vídeo, el formulario SHALL permitir subir un archivo
`video/mp4` de hasta 50 MiB y mostrar su previsualización antes de guardar.

#### Scenario: Se selecciona un vídeo válido
- **WHEN** un admin selecciona un archivo `video/mp4` de 12 MiB para el
  campo de vídeo
- **THEN** el formulario muestra la previsualización de ese vídeo

#### Scenario: Se selecciona un archivo de tipo o tamaño no permitido
- **WHEN** un admin selecciona un archivo que no es `video/mp4`, o que
  supera 50 MiB, para el campo de vídeo
- **THEN** el formulario rechaza el archivo y muestra un mensaje de error,
  sin subirlo

### Requirement: Contenido de tipo pregunta de texto
Cuando el tipo sea Pregunta de texto, el formulario SHALL ofrecer un
textarea para el enunciado que verá el jugador.

#### Scenario: Se escribe el enunciado
- **WHEN** un admin escribe un enunciado en el textarea de pregunta de
  texto
- **THEN** ese texto queda listo para guardarse como `texto_pregunta`

### Requirement: Ubicación real con validación de rango
El formulario SHALL ofrecer campos numéricos de Latitud (-90 a 90) y
Longitud (-180 a 180), y SHALL mostrar un error y bloquear el guardado si
alguno está fuera de rango o vacío.

#### Scenario: Coordenadas válidas
- **WHEN** un admin introduce latitud `41.4036` y longitud `2.1744`
- **THEN** el formulario no muestra error de coordenadas

#### Scenario: Latitud fuera de rango
- **WHEN** un admin introduce una latitud de `120`
- **THEN** el formulario muestra un error indicando que la latitud debe
  estar entre -90 y 90, y bloquea el guardado

### Requirement: Vista previa de mapa no interactiva
El formulario SHALL mostrar una vista previa de mapa de solo lectura con
un pin en las coordenadas de Latitud/Longitud actuales, que se actualiza
cuando cambian esos campos.

#### Scenario: Cambiar las coordenadas mueve el pin
- **WHEN** un admin cambia la latitud o la longitud a un valor válido
- **THEN** la vista previa del mapa actualiza la posición del pin a las
  nuevas coordenadas

### Requirement: Nombre del lugar

El formulario SHALL ofrecer un campo de texto libre obligatorio para el
nombre del lugar, etiquetado de forma que quede claro que es la respuesta
real que se revela al jugador al terminar el desafío — no el nombre de la
pregunta (ese es el campo `nombre`, primero en el formulario).

#### Scenario: Nombre del lugar vacío al guardar

- **WHEN** un admin intenta guardar sin haber escrito el nombre del lugar
- **THEN** el formulario muestra un error en ese campo y bloquea el
  guardado

### Requirement: Nombre corto de la pregunta

El formulario SHALL ofrecer, como primer campo, un texto libre obligatorio
para el nombre corto de la pregunta (p. ej. "Torre Eiffel", "Charles
Darwin"), usado como identificador de esa pregunta en el panel y mostrado
también al jugador junto al objetivo global de la temática.

#### Scenario: Se escribe el nombre corto

- **WHEN** un admin escribe "Torre Eiffel" en el campo de nombre
- **THEN** ese texto queda listo para guardarse como `nombre` del desafío

#### Scenario: Preguntas ya existentes antes de este cambio

- **WHEN** un admin abre para editar una pregunta creada antes de la
  existencia de `desafios.nombre`
- **THEN** el campo aparece precargado con el valor que la migración le
  asignó, editable como cualquier otra pregunta

### Requirement: Pista opcional

El formulario SHALL ofrecer un campo de texto libre opcional para la pista
adicional del desafío, indicando que por ahora no se muestra en ningún
sitio salvo este propio formulario.

#### Scenario: Se guarda una pregunta sin pista

- **WHEN** un admin guarda una pregunta sin escribir nada en el campo de
  pista
- **THEN** la pregunta se guarda con `pista` nula, sin bloquear el
  guardado

#### Scenario: Se guarda una pregunta con pista

- **WHEN** un admin escribe un texto en el campo de pista y guarda
- **THEN** la pregunta se guarda con ese texto en `pista`

### Requirement: Estado activo/inactivo
El formulario SHALL ofrecer un control para marcar la pregunta como activa
o inactiva, activa por defecto al crear.

#### Scenario: Se crea una pregunta inactiva
- **WHEN** un admin desmarca el estado antes de guardar una pregunta nueva
- **THEN** la pregunta se guarda con `activo = false`

### Requirement: Selector de temática obligatorio
El formulario SHALL ofrecer un selector obligatorio de temática (`tematica_id`), listando las temáticas existentes, y SHALL bloquear el guardado si no se elige ninguna. Este campo sustituye a la asignación indirecta de temática que hoy se deducía de a qué nivel se asignaba la pregunta.

#### Scenario: Guardar sin elegir temática
- **WHEN** un admin intenta guardar una pregunta nueva sin seleccionar ninguna temática
- **THEN** el formulario bloquea el guardado y muestra un error en ese campo

#### Scenario: Preguntas ya existentes antes de este cambio
- **WHEN** un admin abre para editar una pregunta creada antes de la existencia de `desafios.tematica_id`
- **THEN** el selector muestra la temática que la migración le asignó, editable como cualquier otra pregunta

### Requirement: Selector de dificultad
El formulario SHALL mostrar el selector de dificultad definido en `question-difficulty`, con los 5 valores del catálogo, y SHALL bloquear el guardado si no se elige ninguno.

#### Scenario: Se cambia la dificultad de una pregunta existente
- **WHEN** un admin edita una pregunta existente y cambia su dificultad de "Normal" a "Difícil"
- **THEN** al guardar, la fila de `desafios` queda con `dificultad = 'dificil'`

### Requirement: Validación de campos obligatorios según el tipo

El formulario SHALL bloquear el guardado y señalar los campos con error
cuando falte el contenido obligatorio para el tipo elegido (imagen, vídeo
o texto), el nombre corto de la pregunta, el nombre del lugar, o
coordenadas válidas.

#### Scenario: Tipo imagen sin archivo

- **WHEN** un admin intenta guardar con tipo "Imagen" sin haber
  seleccionado ningún archivo (ni existir uno previo en edición)
- **THEN** el formulario bloquea el guardado y muestra un error en el
  campo de imagen

#### Scenario: Nombre corto vacío

- **WHEN** un admin intenta guardar sin haber escrito el nombre corto de la
  pregunta
- **THEN** el formulario bloquea el guardado y muestra un error en ese
  campo

### Requirement: Guardar crea o actualiza la pregunta
Al guardar, el formulario SHALL subir el archivo de media (si el tipo lo
requiere y se seleccionó uno nuevo) y crear o actualizar la fila
correspondiente en `desafios`; tras un guardado exitoso SHALL volver al
listado de preguntas.

#### Scenario: Crear una pregunta de tipo imagen
- **WHEN** un admin completa el formulario con tipo "Imagen", una imagen
  válida, coordenadas válidas y nombre del lugar, y pulsa "Guardar"
- **THEN** el archivo se sube al bucket `challenge-media`, se crea la fila
  en `desafios` con la URL resultante, y el panel vuelve al listado
  mostrando la nueva pregunta

#### Scenario: Editar una pregunta sin cambiar su media
- **WHEN** un admin abre una pregunta existente de tipo "Imagen", cambia
  solo el nombre del lugar y guarda sin tocar el campo de imagen
- **THEN** la fila de `desafios` se actualiza conservando la misma
  `imagen_url`

#### Scenario: El guardado falla
- **WHEN** el guardado de una pregunta falla (error de red o del
  servidor)
- **THEN** el formulario muestra un mensaje de error y conserva los datos
  introducidos, sin navegar al listado

### Requirement: Cancelar vuelve al listado sin guardar
El botón "Cancelar" SHALL volver al listado de preguntas sin persistir
ningún cambio del formulario.

#### Scenario: Cancelar una edición
- **WHEN** un admin modifica campos de una pregunta existente y pulsa
  "Cancelar"
- **THEN** el panel vuelve al listado y la pregunta conserva sus valores

### Requirement: Campo opcional de país en el formulario de preguntas

El formulario de preguntas del panel SHALL incluir un campo opcional `pais` (país real del objetivo), independiente del campo de lugar real (`nombre_lugar`), que no bloquea el guardado si se deja vacío.

#### Scenario: Se guarda una pregunta sin país

- **WHEN** un admin guarda una pregunta sin rellenar el campo `pais`
- **THEN** la pregunta se guarda con normalidad, con `pais` vacío

#### Scenario: Se guarda una pregunta con país

- **WHEN** un admin rellena el campo `pais` y guarda la pregunta
- **THEN** la pregunta se guarda con ese país
  previos
