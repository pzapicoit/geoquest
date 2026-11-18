## ADDED Requirements

### Requirement: Cerrar la sesión local no depende de la respuesta del servidor

El resultado de cerrar la sesión activa del dispositivo SHALL decidirse por el estado local, no por la respuesta del servidor. Aplica al entrar como invitado, dar de alta un jugador, cambiar de jugador o descartar uno sin contraseña:

- si la llamada de cierre falla pero la sesión local ya no existe, la operación
  SHALL considerarse cerrada y el flujo SHALL continuar como si hubiera ido bien;
- si la llamada de cierre falla y la sesión local sigue existiendo, la operación
  SHALL tratarse como fallida, como hasta ahora.

#### Scenario: El servidor devuelve 500 al cerrar la sesión antes de entrar como invitado

- **WHEN** el jugador pulsa «Entrar sin cuenta como invitado» con una sesión
  activa
- **AND** el cierre de la sesión responde con un error del servidor después de
  haber soltado la sesión local
- **THEN** se crea la sesión anónima nueva y el jugador entra con un apodo
  sugerido
- **AND** no se muestra ningún mensaje de error

#### Scenario: El servidor falla al cerrar la sesión durante un cambio de jugador

- **WHEN** un jugador con contraseña elige «cambiar de jugador»
- **AND** el cierre de la sesión responde con un error después de haber soltado
  la sesión local
- **THEN** el cambio se completa: se olvida el apodo guardado y la app queda
  lista para que entre otro jugador

#### Scenario: El cierre falla y la sesión local sigue activa

- **WHEN** el cierre de la sesión lanza un error
- **AND** la sesión local sigue existiendo después del error
- **THEN** la operación se informa como fallida
- **AND** no se crea ninguna sesión nueva ni se olvida el apodo guardado
