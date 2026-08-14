# Diseño — INT-73

## Context

El proyecto de Supabase ya existe (creado el 2026-08-14): ref
`xhrntgsdlnwrvwehqfgl`, región `eu-west-1`, Postgres 17.6.1, `ACTIVE_HEALTHY`.
No está linkado a ningún repositorio y no tiene migraciones.

El monorepo tiene tres carpetas —`backend/`, `panel/`, `app/`— y ninguna contiene
código todavía. La arquitectura del producto no contempla un backend propio: los
dos clientes hablan con Supabase directamente.

Estado de la máquina de desarrollo actual:

| Herramienta | Estado |
|---|---|
| Supabase CLI | instalado y autenticado |
| Docker | **no disponible / parado** |
| Flutter SDK | **no instalado** |
| Node | v26.6.0 |

## Goals / Non-Goals

**Goals:**

- Entorno de Supabase reproducible desde el repo.
- Reparto de claves seguro y explícito entre app, panel y scripts.
- Arranque local documentado.
- App Flutter con cliente Supabase inicializado y conectividad verificable.

**Non-Goals:**

- Diseñar el esquema de datos — es INT-74.
- Configurar Storage — es INT-76.
- Escribir políticas RLS — es INT-77. Aquí solo se fija la restricción que las
  condiciona.
- Crear el panel — es INT-80 en adelante. Aquí solo se documenta que comparte
  proyecto.

## Decisions

### D1. Claves nuevas (`sb_publishable_` / `sb_secret_`) y desactivar las legacy

El issue nombra `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY`. El proyecto
tiene ambos formatos activos: las dos legacy y las dos nuevas.

Se adoptan las nuevas y se desactivan las legacy, por tres razones:

1. **Revocabilidad individual.** Las legacy son JWT firmados con el secreto del
   proyecto: revocar una obliga a rotar el secreto, lo que invalida la otra y
   todas las sesiones de usuario vivas. Las nuevas se revocan una a una.
2. **Exposición ya ocurrida.** `supabase projects api-keys` imprime las claves
   legacy **en claro y sin pedir `--reveal`** — las nuevas sí salen enmascaradas.
   La `service_role` legacy de este proyecto ya ha quedado registrada en la
   salida de un terminal durante esta tarea. Esa clave se salta RLS por completo.
3. Es el formato al que Supabase está migrando; empezar en el legacy sería nacer
   con deuda.

*Alternativa considerada:* usar las legacy por fidelidad literal al enunciado del
issue. Descartada — el enunciado se escribió antes de saber que el proyecto
vendría con los dos formatos, y el coste de cambiar más adelante crece con cada
cliente que las consuma.

Mapeo respecto al issue: `SUPABASE_ANON_KEY` → `SUPABASE_PUBLISHABLE_KEY`;
`SUPABASE_SERVICE_ROLE_KEY` → `SUPABASE_SECRET_KEY`.

### D2. La clave secreta no entra en el panel

Es la decisión con más alcance de esta tarea. El panel es una web de
administración; su bundle es público para quien lo descargue. Una clave secreta
ahí equivale a dar acceso total a la base de datos.

Por tanto el panel usa la clave publicable como cualquier otro cliente, y sus
privilegios salen de **políticas RLS sobre el rol del usuario autenticado**.

Esto restringe INT-77: el diseño de RLS tendrá que contemplar un rol de
administrador, no solo el reparto jugador/anónimo. Y restringe INT-80 (login del
panel): necesita autenticación real de Supabase, no una contraseña comparada en
cliente.

La clave secreta vive únicamente en `backend/.env.local`, para migraciones y
seeds ejecutados desde la máquina de desarrollo.

### D3. `supabase init` dentro de `backend/`

El CLI se inicializa en `backend/`, no en la raíz. Así `backend/supabase/`
contiene config y migraciones, y la raíz del monorepo no se llena de artefactos
de una sola de las tres carpetas.

*Coste:* los comandos del CLI hay que lanzarlos desde `backend/` o con
`--workdir backend`. Se documenta en el README.

### D4. Configuración de Flutter por `--dart-define`

Flutter no tiene ficheros `.env` nativos, y meter un `.env` como asset lo empaqueta
legible dentro del binario. Se usa `--dart-define-from-file` con un JSON local no
versionado, leído en código con `String.fromEnvironment`.

*Alternativa considerada:* el paquete `flutter_dotenv`. Descartada: mete el
fichero como asset, es decir, deja los valores extraíbles del `.apk`/`.ipa`.
Para la clave publicable no sería grave —está pensada para ser pública— pero fija
un patrón que sí sería grave el día que alguien meta otra cosa ahí.

### D5. La verificación de conectividad usa el health de Auth

INT-74 aún no existe, así que no hay tablas que consultar.

La comprobación se apoya en `GET /auth/v1/health`, que responde 200 con la clave
publicable y con la base vacía.

**No** se usa la raíz de PostgREST (`GET /rest/v1/`). Verificado contra el
proyecto: con el formato nuevo de claves ese endpoint devuelve 401 con la clave
publicable — *"Only secret API keys can be used for this endpoint"*— y solo
responde 200 con la secreta. Es intencionado: la introspección del esquema ya no
se expone a clientes públicos. Los endpoints de datos (`/rest/v1/<tabla>`) sí
funcionan con la publicable; con la base vacía devuelven 404 de tabla inexistente,
que confirma que la clave autentica pero no sirve como señal de salud.

Efecto lateral a tener en cuenta en INT-74: cualquier herramienta que genere tipos
o clientes por introspección del esquema necesitará la clave secreta, no la
publicable.

## Risks / Trade-offs

- **La `service_role` legacy está comprometida** → se desactiva dentro de esta
  tarea. Mientras siga activa, cualquiera con esa cadena tiene acceso total al
  proyecto saltándose RLS. Es lo primero de `tasks.md`.
- **Docker no está disponible en la máquina** → el stack local no arranca hasta
  instalarlo. Mitigación: el resto de la tarea (link, claves, app) no lo necesita,
  y el README documenta el requisito. No lo instalo yo: es una instalación pesada
  y una decisión del usuario.
- **Flutter no está instalado** → bloquea la parte de app. Misma mitigación:
  queda documentado como prerrequisito y aislado al final de `tasks.md`, para que
  la parte de backend pueda cerrarse sin él.
- **Trabajar contra el proyecto remoto sin stack local** → tentador mientras
  falte Docker, pero significa aplicar cambios a mano y perder el versionado de
  migraciones justo cuando INT-74 va a crear el esquema. Se documenta como algo a
  evitar.

## Migration Plan

No hay nada en producción ni usuarios. La desactivación de las claves legacy no
rompe nada porque ningún cliente las consume todavía — es exactamente el momento
más barato para hacerlo.

Rollback: reactivar las claves legacy desde el dashboard.

## Open Questions

- Región `eu-west-1` (Irlanda) ya elegida. El criterio del issue era "la más
  cercana a los usuarios objetivo"; si el público objetivo es España, encaja. Si
  se apunta a Latinoamérica, convendría revisarlo — pero mover un proyecto de
  región implica recrearlo, así que conviene confirmarlo ahora y no después de
  INT-74.
- Gestión del SDK de Flutter: instalación directa vs `fvm` para fijar versión.
  No bloquea esta tarea.
