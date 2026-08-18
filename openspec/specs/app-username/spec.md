# app-username Specification

## Purpose
TBD - created by archiving change int-89-nombre-usuario. Update Purpose after archive.

## Requirements

### Requirement: Campo de apodo obligatorio con validación de longitud
La pantalla "Nombre de usuario" SHALL mostrar un campo de texto para el
apodo del jugador, y SHALL exigir una longitud mínima y máxima antes de
permitir continuar.

#### Scenario: Campo vacío
- **WHEN** el jugador no ha escrito ningún carácter en el campo de apodo
- **THEN** el botón "Empezar a jugar" está deshabilitado

#### Scenario: Apodo por debajo del mínimo
- **WHEN** el jugador escribe un apodo con menos caracteres que el mínimo
  permitido (tras eliminar espacios al inicio y al final)
- **THEN** el botón "Empezar a jugar" permanece deshabilitado
- **AND** se muestra una indicación del mínimo requerido

#### Scenario: Apodo dentro del rango permitido
- **WHEN** el jugador escribe un apodo cuya longitud (tras `trim`) está
  entre el mínimo y el máximo permitidos
- **THEN** el botón "Empezar a jugar" se habilita

#### Scenario: Intento de superar el máximo
- **WHEN** el jugador intenta escribir más caracteres que el máximo
  permitido
- **THEN** el campo no admite caracteres adicionales más allá del máximo

### Requirement: Guardar el apodo y navegar al Mapa de temáticas
Al pulsar "Empezar a jugar" con un apodo válido, el sistema SHALL guardar
el apodo localmente y en el perfil (`profiles`) del jugador, y SHALL
navegar al Mapa de temáticas.

#### Scenario: Guardado correcto
- **WHEN** el jugador pulsa "Empezar a jugar" con un apodo válido
- **THEN** el apodo se guarda en el almacenamiento local del dispositivo
- **AND** el apodo se guarda en el campo `nombre` del perfil del jugador
- **AND** la app navega al Mapa de temáticas

#### Scenario: Fallo al guardar el apodo remotamente
- **WHEN** el jugador pulsa "Empezar a jugar" con un apodo válido y la
  actualización remota del perfil falla (p. ej. sin conectividad)
- **THEN** la pantalla muestra un error explícito y no navega
- **AND** el jugador puede reintentar sin tener que volver a escribir el
  apodo

### Requirement: Sugerencia de apodo aleatorio
La pantalla SHALL ofrecer una acción para rellenar el campo con un apodo
sugerido aleatoriamente, sin que el jugador tenga que escribirlo.

#### Scenario: El jugador pide una sugerencia
- **WHEN** el jugador pulsa el botón de sugerencia de apodo
- **THEN** el campo de texto se rellena con un apodo no vacío tomado de una
  lista de sugerencias

### Requirement: Mensaje de tranquilidad sobre la sesión anónima
La pantalla SHALL mostrar un texto explicando que no se requiere
contraseña y que la cuenta se podrá vincular más adelante sin perder el
progreso.

#### Scenario: El jugador ve la pantalla
- **WHEN** se muestra la pantalla "Nombre de usuario"
- **THEN** es visible un texto que indica que no hay contraseñas y que se
  podrá vincular una cuenta más adelante para no perder el progreso

### Requirement: Acceso rápido como invitado
La pantalla de captura de apodo SHALL ofrecer una acción "Entrar sin cuenta
como invitado" que asigne un apodo aleatorio de la lista de sugerencias y
complete el mismo flujo de guardado (local y remoto) y navegación que el
botón "Empezar a jugar", sin exigir que el jugador escriba nada.

#### Scenario: El jugador entra como invitado sin escribir apodo
- **WHEN** el jugador pulsa "Entrar sin cuenta como invitado" sin haber
  escrito ningún apodo
- **THEN** se le asigna un apodo no vacío tomado de la lista de sugerencias
- **AND** ese apodo se guarda localmente y en el perfil del jugador
- **AND** la app navega al Mapa de temáticas
