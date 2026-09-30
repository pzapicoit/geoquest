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

## Contenido del juego (`seed.sql`)

El esquema lo reconstruyen las migraciones. **El contenido no**: temáticas,
desafíos, camino y valores por dificultad son obra de autor y viven en
`supabase/seed.sql`.

```bash
cd backend
supabase db query --linked -f supabase/seed.sql
```

`supabase db reset` lo ejecuta solo al final (`[db.seed] enabled = true` en
`config.toml`). Todos los bloques son `insert ... on conflict do update`: son
idempotentes, convergen al estado del fichero, y no borran nada — se pueden
aplicar sobre una base ya poblada.

| Tabla | Filas | Qué es |
|---|---|---|
| `dificultad_defaults` | 5 | preguntas por partida y segundos por desafío |
| `tematicas` | 7 | categorías y su arte de portada |
| `desafios` | 143 | el banco de preguntas |
| `camino` | 8 | la secuencia de paradas |

No incluye datos de jugadores (`profiles`, `intentos_nivel`,
`respuestas_desafio`, `progreso_usuario_nivel`, inventarios de comodines): son
datos de uso, no contenido, y cuelgan de `auth.users`.

### Dos cosas que las migraciones ya no reconstruyen

Conviene saber por qué el seed no es opcional:

- **`camino`**: la migración de INT-98 lo poblaba con un `select` sobre
  `niveles`, y esa tabla la eliminó INT-106. Hoy ese `insert` produce **cero
  filas**, así que sin el seed el camino queda vacío y no hay nada que jugar.
- **`dificultad_defaults`**: las migraciones insertan los valores originales
  (8 preguntas, 30-90 s). Los vigentes se ajustaron jugando (4 preguntas,
  20-30 s) y solo existían dentro de la base.

### Las imágenes no están en el seed

`tematicas.imagen_portada` y `desafios.imagen_url` son URLs absolutas al bucket
público `challenge-media` de este proyecto. Al ser público, esas filas funcionan
desde cualquier proyecto sin credenciales. La contrapartida es que las imágenes
siguen alojadas aquí: una copia autosuficiente exigiría resubir los ficheros y
reescribir las URLs.

### Cómo se regenera

El fichero se genera **desde la base**, no se edita a mano. Si creas contenido
desde el panel y te importaría perderlo, vuelve a volcarlo: se leen las cuatro
tablas por REST con la clave secreta y se emiten los `insert` en orden de clave
ajena (`tematicas` antes de `desafios` y `camino`).

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

### Los tres textos que describen el objetivo de un desafío

Se confunden con facilidad porque los tres suenan a «el sitio», y solo uno de
ellos llega al jugador:

| Columna | Papel | Ejemplo |
|---|---|---|
| `nombre` | qué se pregunta; identifica la fila en el panel | `Ghostbusters` |
| `nombre_lugar` | el punto exacto de la respuesta; **no se muestra en la app** | `Parque de bomberos Hook & Ladder 8, Tribeca, Nueva York` |
| `ciudad` | lo que la app rotula al revelar (INT-122) | `Nueva York` |

`ciudad` es nullable, y `NULL` es una respuesta legítima, no un dato pendiente:
el criterio es la localidad **dentro de la cual** está el objetivo, así que un
yacimiento en descampado, un accidente natural o un naufragio se quedan sin ella
—y la app cae a `nombre_lugar`, que para esos casos es el mejor rótulo posible
(`Monte Fuji`, `Stonehenge, Inglaterra`)—. Rellenarla con la localidad más
cercana sería afirmar algo falso. En el banco inicial son 10 de 135.

`ciudad` y `pais` viajan **solo** en la respuesta de `responder_desafio`.
`desafios_para_jugar` y `iniciar_intento_parada` no las exponen: antes de
responder, la ciudad del objetivo es la respuesta.

`proponer-lugares` devuelve las dos por candidato, con el mismo criterio de
`NULL`, y la descripción que genera sigue sin poder nombrarlas — es la pista que
lee el jugador.

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

## Autenticación de jugadores: sin email, a propósito

Un jugador entra con **apodo y contraseña**, y en este producto no hay email por
ningún lado: ni envío, ni verificación, ni recuperación (INT-128).

Supabase Auth necesita un identificador para poder usar contraseña, así que se
usa uno **sintético, derivado del apodo en el cliente**:

```
sha256(apodo recortado y en minúsculas) en hexadecimal + "@geoquest.invalid"
```

Por eso en el panel de Auth los usuarios aparecen como cadenas hexadecimales:
no es un dato corrupto. El dominio `.invalid` está reservado por la RFC 2606 y
no puede enrutar correo, así que ese buzón no existe ni puede existir.

Tres consecuencias que conviene tener presentes antes de tocar nada:

**La confirmación de email debe seguir DESACTIVADA en el proyecto remoto.** Es
`enable_confirmations = false` en `config.toml` (`mailer_autoconfirm: true` visto
desde fuera). Si se activa, cada alta queda sin confirmar y **el jugador no puede
iniciar sesión**, mientras el proyecto intenta entregar un correo a un buzón que
no existe. Se comprueba sin credenciales:

```bash
curl -s "$SUPABASE_URL/auth/v1/settings" -H "apikey: $SUPABASE_PUBLISHABLE_KEY" \
  | grep mailer_autoconfirm
```

**El apodo de un jugador con contraseña no se puede cambiar**, y lo impide un
trigger sobre `profiles`. Si la identidad deriva del apodo, renombrarlo deja al
jugador fuera de su cuenta en silencio y sin arreglo: no hay recuperación de
contraseña que valga.

**"Tener contraseña" es tenerla no vacía, no que el campo exista.** GoTrue no
deja `auth.users.encrypted_password` a `null` en las altas anónimas, así que
`encrypted_password is not null` se cumple para todo el mundo. El criterio bueno
es `coalesce(encrypted_password, '') <> ''`, y está en `estado_apodo` y en el
trigger. Costó una migración correctiva descubrirlo.

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

## Las tablas de juego solo se escriben por RPC

`intentos_nivel`, `intento_desafios`, `respuestas_desafio` y
`progreso_usuario_nivel` no tienen ninguna policy de escritura y `anon` /
`authenticated` no tienen privilegios de `insert`, `update`, `delete` ni
`truncate` sobre ellas (INT-137). Con la clave publicable en el cliente, una
policy `insert_own` o `update_own` equivale a dejar que el jugador escriba su
propio puntaje, sus estrellas o su ranking. Un jugador solo **lee** sus filas;
las escribe `iniciar_intento_parada`, `marcar_desafio_mostrado`,
`responder_desafio`, `cerrar_intento_parada` y `usar_comodin`, todas
`security definer` con `set search_path = public`.

Consecuencia al escribir una RPC nueva sobre estas tablas: como `security definer`
se salta RLS, **el filtro por dueño hay que escribirlo a mano**
(`usuario_id = auth.uid()`), y el usuario sale siempre de `auth.uid()`, nunca de
un parámetro. `responder_desafio` exige además que el desafío esté en
`intento_desafios` del intento antes de leer nada de `desafios`.

`tests/test_rls_tablas_juego.sql` lo comprueba (transacción con `rollback`, con
el rol `authenticated`); ejecutarlo tras aplicar una migración que toque estas
tablas:

```bash
supabase db query --linked -f supabase/tests/test_rls_tablas_juego.sql
```

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

**Un jugador crea su cuenta pero no puede entrar después**

Lo primero a mirar es la confirmación de email del proyecto: si está activada,
el alta queda sin confirmar y el acceso falla. Ver "Autenticación de jugadores"
más arriba.
