## MODIFIED Requirements

### Requirement: Campo de apodo obligatorio con validación de longitud
La pantalla de acceso SHALL mostrar un campo de texto para el apodo del jugador y
un campo para su contraseña, y SHALL exigir una longitud mínima y máxima en el
apodo, y la longitud mínima de contraseña del proyecto, antes de permitir
continuar.

#### Scenario: Campo vacío
- **WHEN** el jugador no ha escrito ningún carácter en el campo de apodo
- **THEN** el botón principal está deshabilitado

#### Scenario: Apodo por debajo del mínimo
- **WHEN** el jugador escribe un apodo con menos caracteres que el mínimo
  permitido (tras eliminar espacios al inicio y al final)
- **THEN** el botón principal permanece deshabilitado
- **AND** se muestra una indicación del mínimo requerido

#### Scenario: Contraseña por debajo del mínimo
- **WHEN** el jugador escribe un apodo válido y una contraseña más corta que el
  mínimo permitido
- **THEN** el botón principal permanece deshabilitado
- **AND** se muestra una indicación del mínimo requerido

#### Scenario: Apodo y contraseña dentro del rango permitido
- **WHEN** el jugador escribe un apodo cuya longitud (tras `trim`) está entre el
  mínimo y el máximo permitidos, y una contraseña que alcanza el mínimo
- **THEN** el botón principal se habilita

#### Scenario: Intento de superar el máximo
- **WHEN** el jugador intenta escribir más caracteres que el máximo permitido en
  el apodo
- **THEN** el campo no admite caracteres adicionales más allá del máximo

### Requirement: Guardar el apodo y navegar al Mapa de temáticas
Al pulsar el botón principal con apodo y contraseña válidos, el sistema SHALL
resolver con una sola acción del jugador si ese apodo está libre, si es de un
jugador con contraseña o si es de un jugador sin contraseña, y en consecuencia
SHALL crear el perfil, entrar en él, o rechazar el apodo por ocupado.

En los dos casos en que el jugador acaba dentro, SHALL guardar el apodo en el
almacenamiento local del dispositivo y SHALL navegar al Mapa de temáticas.

#### Scenario: Apodo libre
- **WHEN** el jugador pulsa el botón principal con un apodo válido que nadie usa
- **THEN** queda con un perfil cuyo `nombre` es ese apodo y cuyo progreso está a
  cero
- **AND** el apodo se guarda en el almacenamiento local del dispositivo
- **AND** la app navega al Mapa de temáticas

#### Scenario: Apodo propio con la contraseña correcta
- **WHEN** el jugador pulsa el botón principal con el apodo de un jugador con
  contraseña y la contraseña correcta
- **THEN** la app entra en ese perfil y no muestra ningún error
- **AND** el jugador ve la puntuación, el progreso del camino y el inventario de
  comodines de ese perfil
- **AND** el perfil desde el que se entró queda intacto, con su propio progreso

#### Scenario: Contraseña incorrecta
- **WHEN** el jugador pulsa el botón principal con el apodo de un jugador con
  contraseña y una contraseña equivocada
- **THEN** la pantalla muestra un mensaje específico de contraseña incorrecta,
  distinto del error de conexión
- **AND** no navega ni cambia de perfil
- **AND** el apodo escrito se conserva en el campo

#### Scenario: Apodo ocupado por un jugador sin contraseña
- **WHEN** el jugador pulsa el botón principal con el apodo de un perfil que
  existe y no tiene contraseña
- **THEN** la pantalla indica que ese apodo está ocupado y que elija otro
- **AND** no navega ni altera ningún perfil

#### Scenario: Cambiar de jugador no renombra el perfil anterior
- **WHEN** un jugador entra con un apodo nuevo después de que otro jugador
  hubiera usado este dispositivo
- **THEN** el apodo del jugador anterior sigue existiendo, con su progreso y su
  puesto en la clasificación
- **AND** los dos jugadores tienen progresos independientes

#### Scenario: Fallo de conexión al crear o entrar
- **WHEN** el jugador pulsa el botón principal y la operación remota falla (p. ej.
  sin conectividad)
- **THEN** la pantalla muestra un error explícito y no navega
- **AND** el jugador puede reintentar sin tener que volver a escribir el apodo

### Requirement: Mensaje de tranquilidad sobre la sesión anónima
La pantalla SHALL explicar en un texto breve para qué sirve la contraseña: volver a
entrar en el perfil y recuperar el progreso desde este dispositivo o desde otro.
La pantalla SHALL advertir además de que la contraseña no se puede recuperar. La
pantalla NO SHALL afirmar que no hacen falta contraseñas, ni presentar la
vinculación de una cuenta como la única forma de no perder el progreso.

#### Scenario: El jugador ve la pantalla
- **WHEN** se muestra la pantalla de acceso
- **THEN** es visible un texto que explica que con el apodo y la contraseña se
  vuelve a entrar y se recupera el progreso
- **AND** es visible la advertencia de que la contraseña no se puede recuperar

#### Scenario: No se promete que no hay contraseñas
- **WHEN** se muestra la pantalla de acceso
- **THEN** no se muestra ningún texto que afirme que no hay contraseñas por ahora

### Requirement: Acceso rápido como invitado
La pantalla de acceso SHALL ofrecer una acción "Entrar sin cuenta como invitado"
que deje al jugador con un **perfil nuevo sin contraseña**, con un apodo tomado de
la lista de sugerencias, sin exigir que escriba nada. Esta acción NO SHALL entrar
nunca en un perfil existente: las sugerencias salen de una lista fija y corta, así
que podrían coincidir con el apodo de otro jugador.

#### Scenario: El jugador entra como invitado sin escribir nada
- **WHEN** el jugador pulsa "Entrar sin cuenta como invitado" sin haber escrito
  apodo ni contraseña
- **THEN** queda con un perfil nuevo, sin contraseña, cuyo progreso está a cero
- **AND** ese apodo se guarda localmente y en el perfil del jugador
- **AND** la app navega al Mapa de temáticas

#### Scenario: La sugerencia de invitado ya la usa otro jugador
- **WHEN** el apodo sugerido para el invitado ya pertenece a otro jugador
- **THEN** la app no entra en ese perfil
- **AND** el invitado acaba con un perfil nuevo y un apodo libre

## ADDED Requirements

### Requirement: Ponerse contraseña desde la propia app

La app SHALL ofrecer a un jugador sin contraseña la forma de ponerse una,
conservando su perfil y su progreso, y SHALL explicar para qué sirve: poder volver
a entrar desde otro dispositivo y poder dejar sitio a otro jugador en este.

#### Scenario: Un invitado se pone contraseña

- **WHEN** un jugador sin contraseña pide ponerse una y la introduce cumpliendo el
  mínimo
- **THEN** su perfil pasa a tener contraseña sin cambiar de apodo ni perder
  progreso
- **AND** puede entrar con ese apodo y contraseña desde otro dispositivo
