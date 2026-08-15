## ADDED Requirements

### Requirement: Sesión anónima automática en el primer arranque

La app SHALL crear una sesión anónima de Supabase Auth automáticamente en el
primer arranque, sin mostrar ninguna pantalla de registro ni pedir email o
contraseña.

#### Scenario: Primer arranque sin sesión previa

- **WHEN** la app arranca en un dispositivo sin sesión guardada
- **THEN** crea una sesión anónima contra Supabase Auth sin intervención del
  usuario
- **AND** el usuario llega directamente al juego, sin pantalla de registro

#### Scenario: Fallo al crear la sesión anónima

- **WHEN** la creación de la sesión anónima falla (p. ej. sin conexión o el
  proveedor anónimo está deshabilitado)
- **THEN** la app muestra un estado de error explícito con opción de
  reintentar
- **AND** no deja al usuario en una pantalla a medias sin sesión ni mensaje

### Requirement: Persistencia de la sesión entre reinicios

La app SHALL persistir la sesión (anónima o vinculada) de forma segura en el
dispositivo, de modo que reabrir la app no vuelva a pedir acceso.

#### Scenario: Reabrir la app con sesión existente

- **WHEN** el usuario cierra y vuelve a abrir la app en el mismo dispositivo
- **THEN** la app restaura la sesión guardada sin crear una sesión anónima
  nueva
- **AND** el usuario llega directamente al juego con su progreso disponible

### Requirement: Perfil por defecto para usuarios anónimos

El sistema SHALL crear automáticamente la fila en `profiles` para cada alta
anónima, con un nombre por defecto y rol `jugador`, sin intervención manual.

#### Scenario: Alta anónima dispara la creación del perfil

- **WHEN** se crea un nuevo usuario anónimo en `auth.users`
- **THEN** un trigger crea la fila correspondiente en `profiles`
- **AND** el nombre por defecto sigue el patrón "JugadorNNNN" y el rol es
  `jugador`

### Requirement: Vinculación del perfil con el UUID del dispositivo

El sistema SHALL asociar a cada perfil anónimo el UUID del dispositivo que
originó el alta, como identificador provisional del dueño de esa sesión
mientras no exista una identidad vinculada (Google/Apple).

#### Scenario: El alta anónima registra el UUID del dispositivo

- **WHEN** la app crea la sesión anónima en el primer arranque
- **THEN** envía el UUID del dispositivo junto con el alta
- **AND** el perfil creado en `profiles` queda con ese UUID asociado

#### Scenario: Reinstalación de la app en el mismo dispositivo

- **WHEN** el usuario reinstala la app en un dispositivo donde ya existía un
  UUID de dispositivo generado anteriormente
- **THEN** la nueva sesión anónima registra un perfil distinto (no se
  recupera el anterior por este mecanismo)
- **AND** el UUID vuelve a asociarse al nuevo perfil, sin ambigüedad de a
  qué perfil pertenece

### Requirement: Vinculación de identidad Google/Apple sin perder progreso

El sistema SHALL permitir vincular una identidad Google o Apple sobre una
sesión anónima existente (`linkIdentity`), conservando el mismo `user id` y,
por tanto, todo el progreso acumulado.

#### Scenario: Vinculación exitosa

- **WHEN** un usuario con sesión anónima decide vincular su cuenta de Google
- **THEN** la identidad se añade al mismo usuario sin generar un `user id`
  nuevo
- **AND** el progreso registrado antes de vincular sigue asociado al mismo
  perfil

#### Scenario: La identidad ya está en uso por otra cuenta

- **WHEN** la cuenta de Google/Apple que se intenta vincular ya pertenece a
  otro usuario
- **THEN** la vinculación falla con un mensaje explícito
- **AND** la sesión anónima original permanece intacta, sin progreso perdido
