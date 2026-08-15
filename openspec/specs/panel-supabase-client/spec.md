# panel-supabase-client Specification

## Purpose
TBD - created by archiving change int-80-panel-login. Update Purpose after archive.

## Requirements

### Requirement: El panel inicializa un cliente Supabase

El panel SHALL inicializar el cliente de Supabase durante el arranque, antes
de renderizar la primera pantalla, y SHALL fallar de forma explícita si la
configuración no está presente.

#### Scenario: Arranque con configuración correcta

- **WHEN** el panel arranca con la URL y la clave publicable definidas
- **THEN** el cliente de Supabase queda disponible para el resto del panel

#### Scenario: Arranque sin configuración

- **WHEN** el panel arranca sin URL o sin clave publicable
- **THEN** falla en el arranque con un mensaje que nombra la variable ausente
- **AND** no queda en un estado a medias que falle más tarde en una pantalla

### Requirement: Configuración inyectada en tiempo de compilación

El panel SHALL leer la URL y la clave publicable desde variables de entorno
de Vite, y estos valores MUST NOT estar escritos en el código fuente
versionado.

#### Scenario: Compilación del panel

- **WHEN** se compila con `VITE_SUPABASE_URL` y `VITE_SUPABASE_PUBLISHABLE_KEY`
  definidas en el entorno
- **THEN** el panel usa esos valores

#### Scenario: Revisión del código fuente

- **WHEN** se inspecciona el repositorio
- **THEN** no aparece ninguna clave real, solo referencias a las variables de
  entorno (`panel/.env.example`)
