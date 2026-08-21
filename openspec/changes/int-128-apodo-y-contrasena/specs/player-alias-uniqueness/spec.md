## MODIFIED Requirements

### Requirement: Alias único entre jugadores
El sistema SHALL impedir que dos perfiles con `role = 'jugador'` compartan el
mismo `nombre`. La unicidad es lo que permite que un apodo identifique a un
jugador y solo a uno, y con este cambio pasa a ser además la base de su
credencial: la identidad interna con la que entra deriva de su apodo.

Dos apodos que solo difieran en mayúsculas o en espacios sobrantes SHALL
considerarse el mismo a efectos de dar de alta un jugador nuevo, para que no
existan perfiles confundibles entre sí de los que solo uno sea el legítimo.

#### Scenario: Alta anónima con alias por defecto colisionado
- **WHEN** el generador de alias por defecto del alta anónima produce un candidato que ya usa otro jugador
- **THEN** el alta reintenta con otro candidato hasta encontrar uno libre, sin que el registro falle

#### Scenario: El jugador escribe el apodo de un jugador con contraseña
- **WHEN** un jugador escribe en la pantalla de acceso el apodo de otro jugador que tiene contraseña
- **THEN** la app trata ese apodo como un acceso a ese perfil y pide su contraseña, no como un alias que renombrar
- **AND** sin la contraseña correcta no se entra ni se altera nada

#### Scenario: El jugador escribe el apodo de un jugador sin contraseña
- **WHEN** un jugador escribe en la pantalla de acceso el apodo de otro jugador que no tiene contraseña
- **THEN** se le indica que ese apodo está ocupado y que elija otro
- **AND** no se renombra ningún perfil

#### Scenario: Alta con un apodo que solo difiere en mayúsculas
- **WHEN** existe el jugador "Pablo" con contraseña y otra persona intenta darse de alta como "pablo"
- **THEN** el alta no crea un perfil nuevo
- **AND** se le pide la contraseña de "Pablo" o se le indica que elija otro apodo

#### Scenario: Migración de alias que solo difieren en mayúsculas
- **WHEN** se aplica la migración sobre perfiles de jugador cuyos alias coinciden salvo por mayúsculas o espacios sobrantes (p. ej. "Pablo" y "pablo")
- **THEN** se conserva el alias del jugador más antiguo de cada grupo y a los demás se les añade un sufijo numerado
- **AND** a partir de entonces el sistema impide crear alias que solo difieran en mayúsculas, porque derivarían la misma credencial y el segundo jugador perdería el acceso a su perfil sin posibilidad de recuperarlo

#### Scenario: Migración de datos existentes duplicados
- **WHEN** se aplica la migración sobre perfiles con alias duplicados
- **THEN** se conserva el alias del perfil más antiguo de cada grupo (por fecha de alta) y a los demás se les añade un sufijo numerado (" (2)", " (3)"...), truncando la parte base si hace falta para no superar los 16 caracteres permitidos
