# backend

Supabase: esquema, RLS, storage, funciones y vistas que consumen `app/` y `panel/`.

No hay backend custom. La app y el panel atacan este mismo proyecto vía REST y RPC.

- **Proyecto remoto**: `xhrntgsdlnwrvwehqfgl` · región `eu-west-1` · Postgres 17.6
- **Dashboard**: https://supabase.com/dashboard/project/xhrntgsdlnwrvwehqfgl

---

## Cómo se trabaja aquí

**Remote-first.** Las migraciones se escriben en local y se aplican al proyecto
remoto con `supabase db push`. No hace falta Docker.

El stack local es opcional y está diferido hasta **INT-77 (políticas RLS)**, que
es donde empieza a hacer falta de verdad: probar RLS exige crear usuarios y
sesiones desechables, y hacerlo contra el proyecto real deja basura permanente en
`auth`.

| | Para qué | Comprobar |
|---|---|---|
| [Supabase CLI](https://supabase.com/docs/guides/cli) | todo | `supabase --version` |
| Docker Desktop | solo el stack local (opcional hoy) | `docker info` |

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

## Migraciones (flujo habitual)

```bash
supabase migration new <nombre>   # crea el fichero en supabase/migrations/
supabase db push                  # aplica lo pendiente en el remoto
supabase migration list           # compara historial local vs remoto
supabase db reset --linked        # reaplica TODA la cadena desde cero en el remoto
```

Los cambios de esquema van **siempre** por migración versionada, nunca a mano por
el SQL editor del dashboard. Si se tocan a mano, el repo deja de ser la fuente de
verdad y el siguiente `db reset --linked` los borra sin avisar. `migration list`
es lo que delata esa divergencia.

> ⚠️ `db reset --linked` actúa sobre el **proyecto real**. Mientras no haya stack
> local, es el único entorno que existe: borra y reconstruye. Por eso el contenido
> de trabajo debe vivir en el seed, no solo dentro de la base.

## Edge Functions

Hay dos, y existen por una sola razón: **custodiar la clave de OpenAI**. El panel
no puede llamar a OpenAI directamente porque su bundle es público, así que la
llamada se hace desde una función que lee la clave de su entorno.

| Función | Qué hace |
|---|---|
| `proponer-lugares` | Propone lugares reales para una tanda de preguntas (una invocación por tanda) |
| `generar-imagen-lugar` | Ilustra un lugar en estilo Pixar (**una invocación por imagen**) |

Ambas exigen que quien las invoca tenga `profiles.role = 'admin'`, y no usan la
clave secreta: hablan con la base con la clave publicable más el `Authorization`
del invocador, así que RLS sigue siendo la frontera.

```bash
cd backend
supabase functions deploy proponer-lugares generar-imagen-lugar
```

No hace falta Docker para desplegar. `supabase functions serve` (ejecución local)
sí lo pide, así que **la forma de probarlas es desplegadas** contra el proyecto
remoto, igual que las migraciones.

### Secretos y variables de las funciones

```bash
supabase secrets list --project-ref xhrntgsdlnwrvwehqfgl
supabase secrets set geo_open_api=sk-... --project-ref xhrntgsdlnwrvwehqfgl
```

| Variable | Obligatoria | Valor por defecto |
|---|---|---|
| `geo_open_api` | sí | — (sin ella la función responde `secreto_no_configurado`) |
| `GEOQUEST_MODELO_TEXTO` | no | `gpt-4.1` |
| `GEOQUEST_MODELO_IMAGEN` | no | `gpt-image-1` |
| `GEOQUEST_PUBLISHABLE_KEY` | no | la que inyecta la plataforma |

Los **valores no se versionan**: el repo documenta qué secretos hacen falta y
para qué, nunca su contenido. `supabase secrets list` devuelve solo el nombre y
un digest, así que sirve para comprobar que están sin revelarlos.

> ⚠️ **Pon el `--project-ref` explícito.** El selector de proyecto del dashboard
> se queda en el último que abriste, y un secreto creado en el proyecto vecino no
> da ningún error: simplemente la función de GeoQuest no lo encuentra.

Cambiar de modelo es un `secrets set` y una invocación nueva, sin redeploy de
código. Si el modelo por defecto no está habilitado en la cuenta de OpenAI, la
función responde `openai_error` y el panel lo cuenta como "la IA no ha
respondido"; el motivo real está en los logs de la función (dashboard → Edge
Functions → Logs; esta versión del CLI no tiene `functions logs`).

**Elige modelo de texto por velocidad, no por potencia.** Medido contra este
prompt: `gpt-4.1` devuelve 3 lugares con coordenadas correctas en ~4 s, mientras
`gpt-5` agotó el límite de 90 s sin responder — es un modelo de razonamiento y
aquí no se le pide razonar, se le pide recordar lugares reales. Una imagen con
`gpt-image-1` a calidad media tarda ~24 s y pesa ~1,2 MB en WebP.

`GEOQUEST_PUBLISHABLE_KEY` solo hace falta si la comprobación de admin empieza a
fallar para un usuario que sí es admin: significa que la clave publicable que
inyecta la plataforma no vale para este proyecto (las claves legacy de tipo JWT
están desactivadas aquí). Su valor es la `sb_publishable_…` de `.env.local`, que
no es secreta —viaja en el panel y en la app—.

### Estilo de ilustración por temática

`tematicas.prompt_imagen` (texto, opcional) guarda el estilo que
`generar-imagen-lugar` aplica a **todas** las imágenes que la IA genere para esa
temática. Se edita en el panel, en el formulario de la temática.

Gobierna solo **cómo se ve la ilustración**. No decide qué lugares se proponen:
eso lo deduce `proponer-lugares` de las preguntas que la temática ya tiene, y
tener dos fuentes para la misma decisión no tendría forma de resolverse cuando se
contradijeran.

Llega a la función como campo propio, separado de las indicaciones de la tanda, y
manda sobre las reglas genéricas del prompt. Ejemplo real, para «Banderas»:

> la ilustración es la bandera del país sobre fondo neutro, la bandera ocupa todo
> el encuadre, sin escena, sin paisaje, sin edificios y sin gente

Sin ese estilo, el modelo dibuja la bandera dentro de una escena de ciudad — que
rompe la coherencia con el resto de la temática y da pistas de la respuesta.

### Calidad

```bash
cd backend/supabase/functions
deno check proponer-lugares/index.ts generar-imagen-lugar/index.ts
deno lint
```

La lógica que se puede equivocar en silencio (deduplicación de lugares, orden del
lote, traducción de errores) no vive aquí sino en `panel/src/lib/`, donde hay
tests. Estas funciones se limitan a autorizar, construir el prompt y hablar con
OpenAI.

## Stack local (opcional, diferido a INT-77)

Requiere Docker Desktop arrancado.

```bash
supabase start     # levanta el stack
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
