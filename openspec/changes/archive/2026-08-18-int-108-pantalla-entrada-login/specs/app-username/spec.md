## ADDED Requirements

### Requirement: Acceso rápido como invitado
La pantalla de captura de apodo SHALL ofrecer una acción "Entrar sin cuenta como invitado" que asigne un apodo aleatorio de la lista de sugerencias y complete el mismo flujo de guardado (local y remoto) y navegación que el botón "Empezar a jugar", sin exigir que el jugador escriba nada.

#### Scenario: El jugador entra como invitado sin escribir apodo
- **WHEN** el jugador pulsa "Entrar sin cuenta como invitado" sin haber escrito ningún apodo
- **THEN** se le asigna un apodo no vacío tomado de la lista de sugerencias
- **AND** ese apodo se guarda localmente y en el perfil del jugador
- **AND** la app navega al Mapa de temáticas

## REMOVED Requirements

### Requirement: Hueco preparado para iniciar sesión con cuenta existente
**Reason**: El nuevo mock (INT-108) no incluye el enlace "¿Ya tienes una cuenta? Iniciar sesión"; ese hueco visual desaparece de la pantalla de captura de apodo.
**Migration**: El patrón de "hueco preparado para el futuro sin acción" se traslada al enlace "Vincular una cuenta para no perder el progreso" de la nueva pantalla de bienvenida de regreso (ver capability `app-login`).
