# backend

Supabase: esquema, RLS, storage, funciones y vistas que consumen `app/` y `panel/`.

No hay backend custom. La app y el panel atacan este mismo proyecto vía REST y RPC.

- **Proyecto remoto**: `xhrntgsdlnwrvwehqfgl` · región `eu-west-1` · Postgres 17.6
- **Dashboard**: https://supabase.com/dashboard/project/xhrntgsdlnwrvwehqfgl

---

## Prerrequisitos

| | Para qué | Comprobar |
|---|---|---|
| [Supabase CLI](https://supabase.com/docs/guides/cli) | todo | `supabase --version` |
| Docker Desktop **arrancado** | solo el stack local | `docker info` |

Docker solo hace falta para `supabase start`. El link al proyecto remoto y las
migraciones contra él funcionan sin Docker.

## Puesta en marcha

Todos los comandos se lanzan **desde `backend/`** (o con `--workdir backend`),
porque el CLI está inicializado aquí y no en la raíz del monorepo.

```bash
cd backend

# 1. Autenticarse (una vez por máquina)
supabase login

# 2. Linkar con el proyecto remoto
#    El ref no viaja en el clon: supabase/.temp/ está gitignorado.
supabase link --project-ref xhrntgsdlnwrvwehqfgl

# 3. Claves locales
cp .env.example .env.local
supabase projects api-keys --project-ref xhrntgsdlnwrvwehqfgl --reveal
#    …y pega los valores en .env.local
```

## Stack local

```bash
supabase start     # levanta el stack (necesita Docker)
supabase status    # URLs y claves locales
supabase stop      # apaga
supabase db reset  # recrea la base local aplicando todas las migraciones
```

Puertos configurados en `supabase/config.toml`:

| Servicio | Puerto |
|---|---|
| API (PostgREST) | 54321 |
| Base de datos | 54322 |
| Studio | 54323 |
| Inbucket (correo) | 54324 |
| Analytics | 54327 |

Las claves del stack **local** las imprime `supabase status` y no tienen nada que
ver con las del proyecto remoto. No mezcles unas con otras.

## Migraciones

```bash
supabase migration new <nombre>   # crea el fichero en supabase/migrations/
supabase db reset                 # aplica todo en local
supabase db push                  # aplica lo pendiente en el remoto
```

Los cambios de esquema van **siempre** por migración versionada, nunca a mano por
el dashboard. Si se tocan a mano, el repo deja de ser la fuente de verdad y el
siguiente `db reset` los borra sin avisar.

## Claves: quién usa qué

Hay dos claves y la diferencia importa.

| Clave | Quién la usa | Se salta RLS |
|---|---|---|
| `sb_publishable_…` | app, panel | No |
| `sb_secret_…` | scripts de `backend/` | **Sí, por completo** |

La publicable está pensada para viajar dentro de clientes; lo que protege los
datos es RLS, no el secreto de esa clave.

La secreta **no sale de `backend/.env.local`**. En particular no entra en el
panel: su bundle es público para quien lo descargue, así que una clave secreta
ahí equivale a dar acceso total a la base. Los privilegios de administración del
panel salen de políticas RLS sobre el rol del usuario autenticado (INT-77).

`.env.local` está en `.gitignore`. Solo se versiona `.env.example`.

## Problemas frecuentes

**`supabase start` falla con un error de conexión a Docker**

Docker Desktop no está arrancado. `docker info` lo confirma: si responde con
`Cannot connect to the Docker daemon`, ábrelo y espera a que el icono deje de
animarse.

**`Cannot find project ref. Have you run supabase link?`**

Estás fuera de `backend/`, o es un clon nuevo sin linkar. `cd backend` y repite
el paso 2 de la puesta en marcha.

**Las claves de `supabase status` no funcionan contra el proyecto remoto**

Son las del stack local. Para el remoto usa `.env.local`.
