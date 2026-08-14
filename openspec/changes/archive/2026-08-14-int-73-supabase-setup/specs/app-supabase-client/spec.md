# app-supabase-client

## ADDED Requirements

### Requirement: La app inicializa un cliente Supabase

La app Flutter SHALL inicializar el cliente de Supabase durante el arranque,
antes de renderizar la primera pantalla, y SHALL fallar de forma explícita si la
configuración no está presente.

#### Scenario: Arranque con configuración correcta

- **WHEN** la app arranca con la URL y la clave publicable definidas
- **THEN** el cliente de Supabase queda disponible para el resto de la app

#### Scenario: Arranque sin configuración

- **WHEN** la app arranca sin URL o sin clave publicable
- **THEN** falla en el arranque con un mensaje que nombra la variable ausente
- **AND** no queda en un estado a medias que falle más tarde en una pantalla

### Requirement: Configuración inyectada en tiempo de compilación

La app SHALL leer la URL y la clave publicable desde variables de compilación, y
estos valores MUST NOT estar escritos en el código fuente versionado.

#### Scenario: Compilación de la app

- **WHEN** se compila con los valores pasados por `--dart-define`
- **THEN** la app usa esos valores

#### Scenario: Revisión del código fuente

- **WHEN** se inspecciona el repositorio
- **THEN** no aparece ninguna clave real, solo referencias a las variables

### Requirement: Verificación de conectividad

La app SHALL ofrecer una forma de comprobar que alcanza el proyecto de Supabase,
utilizable antes de que exista ningún esquema de datos.

La comprobación SHALL apoyarse en el endpoint de salud de Auth. MUST NOT usar la
raíz de PostgREST, que con el formato nuevo de claves exige clave secreta.

#### Scenario: El proyecto responde

- **WHEN** se ejecuta la comprobación de conectividad contra el proyecto
- **THEN** la app muestra que la conexión es correcta

#### Scenario: El proyecto no responde

- **WHEN** el proyecto está caído o la clave es inválida
- **THEN** la app muestra el fallo y el motivo, sin cerrarse
