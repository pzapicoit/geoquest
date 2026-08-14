# backend-environment

## ADDED Requirements

### Requirement: Entorno de Supabase versionado en el repositorio

El repositorio SHALL contener la configuración del proyecto Supabase bajo
`backend/supabase/`, de forma que cualquier clon del repo pueda reconstruir el
entorno sin pasos manuales en el dashboard.

#### Scenario: Clon limpio del repositorio

- **WHEN** un desarrollador clona el repo y sigue el arranque documentado
- **THEN** llega a un entorno operativo sin haber tocado la consola web
- **AND** todo el esquema procede de migraciones versionadas del repo

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

### Requirement: Flujo de trabajo documentado

`backend/README.md` SHALL documentar el flujo por defecto contra el proyecto
remoto, y SHALL señalar el stack local como opcional junto a su prerrequisito.

#### Scenario: Un desarrollador arranca por primera vez

- **WHEN** sigue el README paso a paso
- **THEN** llega a un entorno operativo contra el proyecto remoto
- **AND** no necesita Docker para llegar ahí

#### Scenario: Se quiere levantar el stack local

- **WHEN** se consulta el README
- **THEN** encuentra los comandos y la advertencia de que requiere Docker
- **AND** encuentra el síntoma concreto de "Docker parado" y su solución

### Requirement: Todo cambio de esquema pasa por migración versionada

Los cambios de esquema SHALL aplicarse mediante ficheros de migración del
repositorio. MUST NOT aplicarse a mano desde el SQL editor del dashboard.

#### Scenario: Se necesita un cambio de esquema

- **WHEN** hay que crear o modificar una tabla, vista, función o política
- **THEN** se crea un fichero de migración y se aplica con `supabase db push`

#### Scenario: El esquema remoto ha divergido del repositorio

- **WHEN** alguien aplicó un cambio a mano por el dashboard
- **THEN** `supabase migration list` revela la divergencia entre el historial
  local y el remoto

#### Scenario: Se reconstruye la base desde cero

- **WHEN** se ejecuta `supabase db reset --linked`
- **THEN** el esquema resultante procede íntegramente de las migraciones del repo
- **AND** cualquier cambio aplicado a mano se pierde

### Requirement: Contenido reproducible por seed

El contenido necesario para trabajar SHALL ser reproducible desde un script de
seed versionado, mientras el proyecto remoto sea el único entorno existente.

#### Scenario: Un reset destruye el contenido

- **WHEN** se ejecuta `supabase db reset --linked` sobre una base con contenido
- **THEN** el seed lo restituye sin intervención manual

### Requirement: Backend único compartido

La app de jugador y el panel de administración SHALL usar el mismo proyecto
Supabase, sin ningún servicio backend intermedio.

#### Scenario: Se documenta la arquitectura

- **WHEN** se consulta `.devplugin/architecture.md`
- **THEN** consta que ambos clientes atacan el mismo proyecto vía REST y RPC
- **AND** consta que no existe backend custom aparte
