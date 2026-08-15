## ADDED Requirements

### Requirement: Formulario de login con email y contraseña

El panel SHALL mostrar un formulario de login con campos de email y
contraseña, sin opción de registro.

#### Scenario: Acceso a la pantalla de login

- **WHEN** un usuario no autenticado abre el panel
- **THEN** ve el formulario de login con campos de email y contraseña
- **AND** no ve ninguna opción de registro o alta de cuenta

### Requirement: Validación de campos vacíos

El formulario de login SHALL validar en cliente que email y contraseña no
estén vacíos antes de intentar autenticar.

#### Scenario: Envío con campos vacíos

- **WHEN** el usuario intenta enviar el formulario con el email o la
  contraseña vacíos
- **THEN** el formulario muestra un error de validación
- **AND** no se realiza ninguna llamada a Supabase Auth

### Requirement: Autenticación contra Supabase Auth

El panel SHALL autenticar el envío del formulario contra Supabase Auth
(email/contraseña), reportando errores explícitos en caso de fallo.

#### Scenario: Credenciales inválidas

- **WHEN** el usuario envía email o contraseña incorrectos
- **THEN** el panel muestra un mensaje de error explícito
- **AND** no se crea ninguna sesión
- **AND** el usuario permanece en la pantalla de login

#### Scenario: Login exitoso

- **WHEN** el usuario envía email y contraseña válidos de una cuenta admin
- **THEN** se crea una sesión autenticada de Supabase
- **AND** el panel redirige a la zona autenticada (Home)

### Requirement: La zona autenticada requiere sesión

El panel SHALL bloquear el acceso a cualquier pantalla más allá del login si
no existe una sesión válida.

#### Scenario: Acceso directo sin sesión

- **WHEN** un usuario sin sesión intenta navegar a una ruta protegida
- **THEN** el panel redirige a la pantalla de login
