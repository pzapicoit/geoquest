# player-anonymous-auth Specification

## Purpose
TBD - created by archiving change int-75-registro-anonimo. Update Purpose after archive.

## Requirements

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
originó el alta, como rastro del origen de esa sesión. Ese UUID NO SHALL usarse
como mecanismo de recuperación de cuenta: la recuperación del progreso se hace con
el apodo y la contraseña del jugador.

#### Scenario: El alta anónima registra el UUID del dispositivo

- **WHEN** la app crea una sesión anónima para un jugador nuevo
- **THEN** envía el UUID del dispositivo junto con el alta
- **AND** el perfil creado en `profiles` queda con ese UUID asociado

#### Scenario: Reinstalación de la app en el mismo dispositivo

- **WHEN** el usuario reinstala la app en un dispositivo donde ya existía un
  UUID de dispositivo generado anteriormente
- **THEN** la nueva sesión anónima registra un perfil distinto (no se recupera el
  anterior por este mecanismo)
- **AND** el jugador puede recuperar su perfil anterior con su apodo y su
  contraseña, si se la había puesto

### Requirement: Vinculación de identidad Google/Apple sin perder progreso

El sistema SHALL permitir vincular una identidad Google o Apple sobre una sesión
existente (`linkIdentity`), conservando el mismo `user id` y, por tanto, todo el
progreso acumulado. Esto SHALL seguir valiendo tanto para una sesión anónima como
para un jugador que ya se haya puesto contraseña.

#### Scenario: Vinculación exitosa

- **WHEN** un usuario con sesión anónima decide vincular su cuenta de Google
- **THEN** la identidad se añade al mismo usuario sin generar un `user id` nuevo
- **AND** el progreso registrado antes de vincular sigue asociado al mismo perfil

#### Scenario: Vinculación sobre un jugador con contraseña

- **WHEN** un jugador que ya tiene contraseña vincula su cuenta de Google
- **THEN** la identidad se añade al mismo usuario sin generar un `user id` nuevo
- **AND** sigue pudiendo entrar con su apodo y su contraseña

#### Scenario: La identidad ya está en uso por otra cuenta

- **WHEN** la cuenta de Google/Apple que se intenta vincular ya pertenece a otro
  usuario
- **THEN** la vinculación falla con un mensaje explícito
- **AND** la sesión original permanece intacta, sin progreso perdido

### Requirement: Asegurar la sesión y cambiar de sesión son operaciones distintas

El sistema SHALL distinguir dos operaciones sobre la sesión:

- **asegurar** la sesión, que no SHALL tocar la sesión existente y solo crea una
  anónima cuando no hay ninguna — es lo que hace el arranque de la app;
- **cambiar** de sesión, que SHALL sustituir la sesión activa por la del jugador
  que se identifica, aunque ya existiera una.

Sin esa distinción, "cambiar de jugador" es imposible: la operación de arranque
cortocircuita en cuanto encuentra una sesión y el jugador nuevo hereda el
`auth.uid()` del anterior.

#### Scenario: Arranque con sesión existente

- **WHEN** la app arranca y ya hay una sesión guardada
- **THEN** la operación de asegurar la sesión la reutiliza sin crear ninguna otra
- **AND** no se altera el perfil activo

#### Scenario: Cambio de sesión con sesión existente

- **WHEN** un jugador se identifica con su apodo y su contraseña habiendo una
  sesión activa
- **THEN** la sesión activa se sustituye por la suya
- **AND** las operaciones posteriores se ejecutan como ese perfil

### Requirement: Un dispositivo puede originar varios perfiles

El sistema SHALL permitir que un mismo dispositivo dé de alta varios perfiles a lo
largo del tiempo. El `device_id` SHALL quedar como el dispositivo que originó cada
alta, sin implicar que sea el único perfil de ese dispositivo ni su dueño
exclusivo.

#### Scenario: Dos jugadores nuevos en el mismo dispositivo

- **WHEN** dos jugadores se dan de alta en el mismo dispositivo con apodos
  distintos
- **THEN** se crean dos perfiles distintos, cada uno con su progreso
- **AND** los dos quedan asociados al mismo `device_id` sin que el alta falle
