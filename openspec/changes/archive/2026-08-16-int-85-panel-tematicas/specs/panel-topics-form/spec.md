## ADDED Requirements

### Requirement: Alta y edición en panel lateral
El botón "Nueva temática" y la acción "Editar" de cada fila SHALL abrir un
panel lateral con el formulario de temática, en vez de navegar a una
pantalla aparte.

#### Scenario: Abrir el panel para crear
- **WHEN** un admin pulsa "Nueva temática"
- **THEN** se abre el panel lateral con el formulario vacío, con el estado
  activo marcado por defecto

#### Scenario: Abrir el panel para editar
- **WHEN** un admin pulsa "Editar" sobre una temática existente
- **THEN** se abre el panel lateral con los datos actuales de esa temática
  precargados

### Requirement: Nombre obligatorio
El formulario SHALL ofrecer un campo de texto obligatorio para el nombre
de la temática, mostrado como título del mundo en el mapa del jugador.

#### Scenario: Guardar sin nombre
- **WHEN** un admin intenta guardar con el campo de nombre vacío
- **THEN** el formulario bloquea el guardado y muestra un error en ese
  campo

### Requirement: Imagen de portada obligatoria con previsualización
El formulario SHALL exigir una imagen de portada (`image/jpeg` o
`image/png`, hasta 4 MB) y mostrar su previsualización antes de guardar;
al crear, SHALL ser obligatoria, y al editar SHALL conservar la portada
existente si no se selecciona un archivo nuevo.

#### Scenario: Se selecciona una portada válida
- **WHEN** un admin selecciona un archivo `image/png` de 1 MB para la
  portada
- **THEN** el formulario muestra la previsualización de esa imagen

#### Scenario: Se selecciona un archivo de tipo o tamaño no permitido
- **WHEN** un admin selecciona un archivo que no es `image/jpeg`/`image/png`,
  o que supera 4 MB, para la portada
- **THEN** el formulario rechaza el archivo y muestra un mensaje de error,
  sin subirlo

#### Scenario: Crear sin seleccionar portada
- **WHEN** un admin intenta guardar una temática nueva sin haber
  seleccionado ninguna imagen de portada
- **THEN** el formulario bloquea el guardado y muestra un error en el
  campo de portada

#### Scenario: Editar sin cambiar la portada
- **WHEN** un admin abre una temática existente y guarda tras modificar
  solo el nombre, sin tocar el campo de portada
- **THEN** la temática se actualiza conservando la misma
  `imagen_portada`

### Requirement: Campo de estrellas requeridas condicionado a la posición
El formulario SHALL mostrar el campo numérico "Estrellas requeridas" salvo
cuando la temática editada (o la que se está creando) ocupe la posición 1
del recorrido, en cuyo caso SHALL ocultarlo y guardar `estrellas_requeridas
= 0`.

#### Scenario: Editar una temática que no es la primera
- **WHEN** un admin edita una temática con `orden = 2`
- **THEN** el formulario muestra el campo de estrellas requeridas con su
  valor actual

#### Scenario: Editar la primera temática del recorrido
- **WHEN** un admin edita la temática con `orden = 1`
- **THEN** el formulario oculta el campo de estrellas requeridas y, al
  guardar, persiste `estrellas_requeridas = 0`

#### Scenario: Crear la primera temática cuando no existe ninguna
- **WHEN** un admin crea una temática y todavía no existe ninguna otra
- **THEN** el formulario oculta el campo de estrellas requeridas y la
  nueva temática se crea con `estrellas_requeridas = 0`

### Requirement: Validación del campo de estrellas requeridas
Cuando el campo de estrellas requeridas esté visible, el formulario SHALL
exigir un valor entero mayor o igual a 0 y bloquear el guardado en caso
contrario.

#### Scenario: Valor negativo
- **WHEN** un admin introduce `-5` en el campo de estrellas requeridas
- **THEN** el formulario bloquea el guardado y muestra un error en ese
  campo

### Requirement: Estado activo/inactivo
El formulario SHALL ofrecer un control para marcar la temática como activa
o inactiva, activa por defecto al crear.

#### Scenario: Se crea una temática inactiva
- **WHEN** un admin desmarca el estado antes de guardar una temática nueva
- **THEN** la temática se guarda con `activo = false`

### Requirement: Guardar crea o actualiza la temática
Al guardar, el formulario SHALL subir la imagen de portada (si se
seleccionó una nueva) a la ruta `tematicas/{tematica_id}.{extension}` del
bucket `challenge-media`, y crear o actualizar la fila correspondiente en
`tematicas`; tras un guardado exitoso SHALL cerrar el panel y volver al
listado actualizado.

#### Scenario: Crear una temática nueva
- **WHEN** un admin completa el formulario con nombre, portada válida y
  estrellas requeridas, y pulsa "Guardar"
- **THEN** la portada se sube al bucket `challenge-media`, se crea la fila
  en `tematicas` al final del recorrido, y el listado la muestra

#### Scenario: El guardado falla
- **WHEN** el guardado de una temática falla (error de red o del
  servidor)
- **THEN** el formulario muestra un mensaje de error y conserva los datos
  introducidos, sin cerrar el panel

### Requirement: Cancelar cierra el panel sin guardar
El botón "Cancelar" SHALL cerrar el panel lateral sin persistir ningún
cambio del formulario.

#### Scenario: Cancelar una edición
- **WHEN** un admin modifica campos de una temática existente y pulsa
  "Cancelar"
- **THEN** el panel se cierra y la temática conserva sus valores previos
