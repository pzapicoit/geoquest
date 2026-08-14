# backend-environment

## ADDED Requirements

### Requirement: Entorno de Supabase versionado en el repositorio

El repositorio SHALL contener la configuración del proyecto Supabase bajo
`backend/supabase/`, de forma que cualquier clon del repo pueda reconstruir el
entorno sin pasos manuales en el dashboard.

#### Scenario: Clon limpio del repositorio

- **WHEN** un desarrollador clona el repo y ejecuta el arranque documentado
- **THEN** obtiene un stack de Supabase local equivalente al remoto, sin haber
  tocado la consola web

#### Scenario: Un clon nuevo necesita saber contra qué proyecto linkar

- **WHEN** un desarrollador consulta `backend/.env.example` o `backend/README.md`
- **THEN** encuentra el ref del proyecto remoto y el comando de link
- **AND** `backend/supabase/config.toml` identifica el stack local como `geoquest`

Nota: el ref remoto lo guarda el CLI en `backend/supabase/.temp/`, que está
gitignorado. Por eso el ref se documenta explícitamente y `supabase link` es un
paso de onboarding, no algo que se herede del clon.

### Requirement: Separación de claves por consumidor

El sistema SHALL distinguir entre clave publicable y clave secreta, y cada
consumidor SHALL recibir únicamente la clave que le corresponde.

La clave secreta se salta Row Level Security por completo, por lo que MUST NOT
llegar a ningún binario ni bundle distribuible.

#### Scenario: La app de jugador se configura

- **WHEN** se construye la app Flutter
- **THEN** recibe la URL del proyecto y la clave publicable
- **AND** no contiene la clave secreta en ningún punto del binario

#### Scenario: El panel de administración se configura

- **WHEN** se construye el panel
- **THEN** recibe la URL del proyecto y la clave publicable
- **AND** sus privilegios de administración provienen de políticas RLS sobre el
  rol del usuario autenticado, no de la clave secreta

#### Scenario: Un script de mantenimiento necesita saltarse RLS

- **WHEN** se ejecuta una tarea de seed o migración desde `backend/`
- **THEN** lee la clave secreta desde un fichero de entorno local no versionado

#### Scenario: Se intenta commitear un fichero de entorno con claves

- **WHEN** un fichero `.env.local` contiene claves reales
- **THEN** `.gitignore` impide que entre al repositorio
- **AND** el repositorio solo contiene `backend/.env.example` con placeholders

### Requirement: Claves legacy desactivadas

El proyecto SHALL operar exclusivamente con el formato de claves
`sb_publishable_…` / `sb_secret_…`, y las claves legacy de tipo JWT (`anon`,
`service_role`) SHALL quedar desactivadas.

#### Scenario: Consulta del listado de claves

- **WHEN** se ejecuta `supabase projects api-keys`
- **THEN** las claves de tipo `legacy` no aparecen como activas

#### Scenario: Una clave se ve comprometida

- **WHEN** es necesario revocar una clave concreta
- **THEN** puede revocarse de forma individual sin invalidar las demás ni
  requerir cambiar el secreto JWT del proyecto

### Requirement: Arranque local documentado

`backend/README.md` SHALL documentar cómo levantar, parar e inspeccionar el
entorno local, incluyendo los prerrequisitos de máquina.

#### Scenario: Un desarrollador levanta el entorno por primera vez

- **WHEN** sigue el README paso a paso
- **THEN** llega a un stack local funcionando
- **AND** el README le ha advertido antes de que necesita Docker en marcha

#### Scenario: Docker no está disponible

- **WHEN** se intenta arrancar el stack local sin Docker
- **THEN** el README describe el síntoma y cómo resolverlo

### Requirement: Backend único compartido

La app de jugador y el panel de administración SHALL usar el mismo proyecto
Supabase, sin ningún servicio backend intermedio.

#### Scenario: Se documenta la arquitectura

- **WHEN** se consulta `.devplugin/architecture.md`
- **THEN** consta que ambos clientes atacan el mismo proyecto vía REST y RPC
- **AND** consta que no existe backend custom aparte
