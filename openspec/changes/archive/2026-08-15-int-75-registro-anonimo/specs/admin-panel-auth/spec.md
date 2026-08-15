## ADDED Requirements

### Requirement: Login por email y contraseña para el panel de administración

El panel de administración SHALL autenticar mediante email y contraseña, como
flujo independiente del inicio de sesión anónimo de la app de jugador.

#### Scenario: Login exitoso

- **WHEN** un administrador introduce email y contraseña válidos
- **THEN** obtiene una sesión autenticada de Supabase Auth asociada a su
  cuenta
- **AND** la fila correspondiente en `profiles` tiene rol `admin`

#### Scenario: Credenciales inválidas

- **WHEN** un administrador introduce email o contraseña incorrectos
- **THEN** el intento de login falla con un mensaje explícito
- **AND** no se crea ninguna sesión

### Requirement: Los flujos anónimo y de administración son independientes

El sistema SHALL mantener el alta anónima (jugador) y el login por
email/contraseña (panel) como mecanismos de autenticación separados: el panel
no ofrece alta anónima, y la app de jugador no expone login por
email/contraseña como paso obligatorio.

#### Scenario: El panel no permite entrar de forma anónima

- **WHEN** se intenta acceder al panel de administración
- **THEN** el único mecanismo disponible es email/contraseña
- **AND** no existe la opción de crear o usar una sesión anónima

Nota: qué rutas o datos puede ver cada rol una vez autenticado lo definen las
políticas de RLS (fuera de alcance de este cambio, ver INT-77).
