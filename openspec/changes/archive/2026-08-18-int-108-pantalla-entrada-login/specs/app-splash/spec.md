## MODIFIED Requirements

### Requirement: Enrutamiento según nombre de usuario guardado
Una vez resuelta la sesión con éxito, el splash SHALL navegar a la pantalla "Nombre de usuario" si el dispositivo no tiene un nombre de usuario guardado todavía, o a la pantalla de bienvenida de regreso (capability `app-login`) si ya lo tiene.

#### Scenario: Primera vez, sin nombre de usuario guardado
- **WHEN** la sesión se resuelve con éxito y no hay nombre de usuario guardado en el dispositivo
- **THEN** la app navega a la pantalla "Nombre de usuario"

#### Scenario: Ya tiene nombre de usuario guardado
- **WHEN** la sesión se resuelve con éxito y ya existe un nombre de usuario guardado en el dispositivo
- **THEN** la app navega a la pantalla de bienvenida de regreso
- **AND** no navega directamente al Mapa de temáticas sin mostrar esa pantalla intermedia
