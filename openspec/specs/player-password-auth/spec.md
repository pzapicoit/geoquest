# player-password-auth Specification

## Purpose
TBD - created by syncing change int-128-apodo-y-contrasena. Update Purpose after archive.

## Requirements

### Requirement: Un jugador se identifica con apodo y contraseña, sin email


El sistema SHALL permitir que un jugador cree su perfil y entre en él con un apodo
y una contraseña, y NO SHALL requerir en ningún momento una dirección de correo
del jugador, ni verificación de correo, ni envío de correo.

La identidad interna que exige el proveedor de autenticación SHALL derivarse del
apodo de forma determinista, sobre un dominio que no pueda recibir correo, y SHALL
ser insensible a mayúsculas y a espacios sobrantes en el apodo.

#### Scenario: Alta de un jugador con apodo libre

- **WHEN** un jugador introduce un apodo que nadie usa y una contraseña válida
- **THEN** queda con un perfil propio cuyo `nombre` es ese apodo y cuyo progreso
  empieza a cero
- **AND** entra en el juego sin ningún paso de verificación

#### Scenario: Acceso desde otro dispositivo

- **WHEN** un jugador con contraseña introduce su apodo y su contraseña en un
  dispositivo distinto del que usó para crear el perfil
- **THEN** entra en su perfil
- **AND** ve su puntuación, su progreso del camino y su inventario de comodines

#### Scenario: El apodo se escribe con otras mayúsculas

- **WHEN** un jugador registrado como "Pablo" introduce "pablo" con su contraseña
- **THEN** entra en su perfil

#### Scenario: Contraseña incorrecta

- **WHEN** un jugador introduce un apodo con contraseña que existe y una
  contraseña que no es la suya
- **THEN** se le indica que la contraseña no es correcta, de forma distinguible de
  un fallo de conexión
- **AND** no cambia la sesión activa

#### Scenario: Longitud mínima de contraseña

- **WHEN** un jugador introduce una contraseña más corta que el mínimo del
  proyecto
- **THEN** no se intenta el alta ni el acceso
- **AND** se le indica el mínimo requerido

### Requirement: Estado de un apodo antes de crear o entrar


El sistema SHALL ofrecer una consulta que, dado un apodo, indique si está libre,
si corresponde a un jugador con contraseña, o si corresponde a un jugador sin
contraseña. Esa consulta SHALL devolver únicamente ese estado: nunca la identidad
interna del jugador, su identificador ni ningún otro dato del perfil.

Sin esa consulta la pantalla no puede distinguir "ese apodo no es tuyo" de "te has
equivocado de contraseña", porque el proveedor de autenticación responde lo mismo
en ambos casos.

#### Scenario: Apodo libre

- **WHEN** se consulta el estado de un apodo que nadie usa
- **THEN** el estado es "libre"

#### Scenario: Apodo de un jugador con contraseña

- **WHEN** se consulta el estado del apodo de un jugador que tiene contraseña
- **THEN** el estado es "con contraseña"

#### Scenario: Apodo de un jugador sin contraseña

- **WHEN** se consulta el estado del apodo de un jugador que aún no tiene
  contraseña
- **THEN** el estado es "sin contraseña"

#### Scenario: La consulta no expone datos del perfil

- **WHEN** se consulta el estado de cualquier apodo
- **THEN** la respuesta no incluye la identidad interna, el identificador del
  jugador ni ningún dato de su progreso

### Requirement: Un apodo ocupado por un jugador sin contraseña no se puede tomar


El sistema SHALL rechazar el alta cuando el apodo pertenece a un jugador sin
contraseña, y SHALL indicarlo como apodo ocupado. No hay credencial que comprobar
para entrar en él, y permitir el alta se lo arrebataría a su dueño.

#### Scenario: Se intenta registrar un apodo de un jugador sin contraseña

- **WHEN** un jugador introduce el apodo de un perfil que existe y no tiene
  contraseña
- **THEN** se le indica que ese apodo está ocupado y que elija otro
- **AND** no se crea ningún perfil ni se altera el existente

### Requirement: Un invitado se convierte en jugador con contraseña sin perder el progreso


El sistema SHALL permitir que un jugador que entró sin contraseña se ponga una,
conservando **el mismo perfil**: su puntuación, su progreso del camino, su
inventario de comodines y su puesto en la clasificación. La conversión NO SHALL
crear un perfil nuevo.

#### Scenario: Un invitado con progreso se pone contraseña

- **WHEN** un jugador que entró como invitado y ha acumulado progreso establece
  una contraseña
- **THEN** conserva el mismo perfil, con su apodo y todo su progreso
- **AND** a partir de ese momento puede entrar con su apodo y esa contraseña desde
  otro dispositivo

#### Scenario: Fallo al establecer la contraseña

- **WHEN** el establecimiento de la contraseña falla (p. ej. sin conexión)
- **THEN** se indica el fallo y se puede reintentar
- **AND** el jugador sigue con su sesión y su progreso intactos

### Requirement: El apodo de un jugador con contraseña no se puede cambiar


El sistema SHALL impedir que se modifique el `nombre` de un perfil cuyo jugador
tiene credenciales, y SHALL impedirlo en la base de datos, no solo en la
aplicación. La identidad interna deriva del apodo, así que renombrarlo dejaría al
jugador sin acceso, de forma silenciosa y sin vuelta atrás.

#### Scenario: Se intenta renombrar un perfil con contraseña

- **WHEN** se intenta actualizar el `nombre` de un perfil cuyo jugador tiene
  credenciales
- **THEN** la operación es rechazada por la base de datos

#### Scenario: Renombrar un perfil sin contraseña sigue permitido

- **WHEN** se actualiza el `nombre` de un perfil cuyo jugador no tiene
  credenciales
- **THEN** la operación se completa con normalidad, sujeta a la unicidad de alias

### Requirement: No hay recuperación de contraseña, y la pantalla lo dice


El sistema NO SHALL ofrecer recuperación de contraseña: sin correo no existe canal
para ello. La pantalla de acceso SHALL advertirlo de forma visible, en vez de
dejar que el jugador lo descubra el día que cambia de dispositivo.

#### Scenario: El jugador ve la pantalla de acceso

- **WHEN** se muestra la pantalla de acceso
- **THEN** es visible una advertencia de que la contraseña no se puede recuperar
- **AND** no se ofrece ningún enlace de "he olvidado mi contraseña"
