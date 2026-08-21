## ADDED Requirements

### Requirement: El dispositivo recuerda los apodos que han entrado en él

Tras entrar con éxito en un perfil —creándolo, accediendo con contraseña o
entrando como invitado—, el sistema SHALL registrar ese apodo en una lista local
del dispositivo, sin duplicados y ordenada del más reciente al más antiguo.

La lista SHALL contener apodos y nada más: nunca contraseñas, ni sesiones, ni
ningún dato que por sí solo permita entrar en un perfil.

#### Scenario: Primer jugador que entra en el dispositivo

- **WHEN** un jugador entra por primera vez en un dispositivo sin lista previa
- **THEN** su apodo queda registrado como único elemento de la lista

#### Scenario: Segundo jugador en el mismo dispositivo

- **WHEN** otro jugador entra en el mismo dispositivo con un apodo distinto
- **THEN** la lista contiene los dos apodos
- **AND** el que acaba de entrar aparece primero

#### Scenario: Vuelve a entrar un apodo ya registrado

- **WHEN** entra un jugador cuyo apodo ya estaba en la lista
- **THEN** la lista no duplica ese apodo
- **AND** ese apodo pasa a aparecer primero

#### Scenario: La lista no guarda credenciales

- **WHEN** se inspecciona lo que el dispositivo ha guardado de la lista
- **THEN** no contiene contraseñas ni sesiones de ningún jugador

### Requirement: Tope de apodos recordados

El sistema SHALL limitar cuántos apodos recuerda el dispositivo, descartando los
menos recientes al superar el tope, para que la lista siga siendo un atajo y no un
historial.

#### Scenario: Se supera el tope de apodos

- **WHEN** entra un jugador nuevo estando la lista en su tope
- **THEN** su apodo se añade al principio
- **AND** desaparece de la lista el apodo que llevaba más tiempo sin entrar

### Requirement: Elegir un apodo recordado rellena el acceso, no lo completa

La pantalla de acceso SHALL ofrecer los apodos recordados como atajo: elegir uno
SHALL rellenar el campo de apodo y dejar al jugador escribiendo directamente su
contraseña. Elegir un apodo NO SHALL entrar en el perfil por sí solo: seguir
haciendo falta la contraseña es justo lo que evita que compartir un móvil sea
compartir las cuentas.

#### Scenario: El jugador elige un apodo de la lista

- **WHEN** el jugador pulsa uno de los apodos recordados
- **THEN** el campo de apodo queda rellenado con ese apodo
- **AND** el foco pasa al campo de contraseña
- **AND** no se ha entrado en ningún perfil todavía

#### Scenario: Un apodo recordado sin contraseña

- **WHEN** el jugador pulsa un apodo recordado que corresponde a un perfil sin
  contraseña y no es el de la sesión activa
- **THEN** se le indica que ese jugador no puede entrar desde aquí porque no tiene
  contraseña

### Requirement: Olvidar un apodo del dispositivo

El sistema SHALL permitir retirar un apodo de la lista local. Retirarlo SHALL
afectar solo a este dispositivo: el perfil remoto, su puntuación y su progreso
quedan intactos y siguen siendo accesibles escribiendo el apodo y la contraseña.

#### Scenario: El jugador olvida un apodo

- **WHEN** el jugador pide olvidar uno de los apodos recordados
- **THEN** ese apodo desaparece de la lista del dispositivo
- **AND** el perfil sigue existiendo y se puede volver a entrar con su contraseña

### Requirement: Sin lista, la pantalla es la de siempre

Cuando el dispositivo no recuerda ningún apodo, la pantalla de acceso SHALL
mostrarse sin sección de apodos recientes, sin hueco vacío que la sustituya.

#### Scenario: Primer arranque de una instalación limpia

- **WHEN** se muestra la pantalla de acceso en un dispositivo sin apodos
  recordados
- **THEN** no se muestra ninguna sección de apodos recientes
