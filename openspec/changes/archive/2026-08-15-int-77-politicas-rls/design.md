## Context

El esquema del juego (INT-74) se creó deliberadamente sin RLS, salvo el
mínimo añadido en `profiles` (INT-76: `enable row level security` +
`profiles_select_own`, sin ninguna policy de `insert`/`update`/`delete`).
Todas las demás tablas (`tematicas`, `niveles`, `desafios`,
`nivel_desafios`, `intentos_nivel`, `respuestas_desafio`,
`progreso_usuario_nivel`) siguen sin RLS: cualquier cliente con la clave
`anon` (incluida una sesión anónima real, INT-75) puede leer y escribir esas
tablas sin restricción vía PostgREST.

El flujo del repo es remote-first (sin Docker local, ver INT-73): las
migraciones se aplican con `supabase db push --linked` contra el proyecto
remoto y se verifican con usuarios de prueba reales (mismo patrón que
INT-76).

## Goals / Non-Goals

**Goals:**
- RLS habilitado en las siete tablas restantes del esquema del juego.
- Una función `is_admin()` reutilizable, en vez de repetir la subconsulta a
  `profiles` en cada policy (como se hizo ad-hoc en INT-76 para
  `storage.objects`).
- Cada jugador solo ve/edita su propio progreso; nadie ve el contenido
  "en crudo" de `desafios` antes de jugar; solo `is_admin()` gestiona
  contenido.
- `profiles` pasa de "sin `update` posible" a "editable por el dueño, salvo
  `role`".

**Non-Goals:**
- Filtrar por `activo` en las policies de lectura de `tematicas`/`niveles`.
  El objetivo aquí es solo "quién puede leer/escribir", no "qué fila
  concreta debe ver el jugador en cada momento" — eso es una decisión de
  las vistas/RPCs de INT-95/INT-87 (`desafios_para_jugar`, etc.), que
  filtrarán además por `activo`.
- La vista `desafios_para_jugar` en sí (INT-95) y las RPCs del panel
  (INT-87). Esta change solo dejar el terreno listo (RLS + `is_admin()`)
  para que esas vistas/RPCs se apoyen en él.
- Un panel de gestión de usuarios/roles. El primer admin se asigna a mano
  (SQL/dashboard de Supabase), fuera de cualquier migración versionada
  porque identifica una fila concreta de un entorno concreto.

## Decisions

### `is_admin()` como función `security invoker`, no `security definer`

La función solo necesita ver la propia fila del usuario que la invoca
(`profiles.id = auth.uid()`), y `profiles_select_own` (INT-76) ya permite
eso. No hace falta saltarse RLS con `security definer` — mantenerla
`invoker` evita ampliar innecesariamente sus privilegios y evita tener que
razonar sobre una función con más acceso del que necesita. Se marca
`stable` (no muta datos, cacheable dentro de la misma sentencia) y
`set search_path = public` (mismo hábito que `handle_new_user`, INT-75).

### `desafios`: sin policy de lectura para jugadores; `is_admin()` sí puede leer

El ticket es explícito en que los jugadores no deben leer `desafios`
directamente (verían `lat_real`/`lng_real`/`nombre_lugar` antes de
responder); ese acceso llegará por la vista `desafios_para_jugar` (INT-95).

Para `is_admin()` sí se añade policy de `select` (además de
`insert`/`update`/`delete`): el objetivo del ticket es que los admins
"gestionen el contenido del juego", y gestionar contenido sin poder leerlo
de vuelta (para confirmarlo o editarlo) no cumple ese objetivo. La
alternativa — dejar `desafios` completamente cerrado incluso para
`is_admin()` hasta que existan las vistas de panel de INT-87 — se descartó
porque dejaría un hueco operativo real durante el tiempo entre INT-77 e
INT-87 sin necesidad: el riesgo de exponer `desafios` a un usuario ya
verificado como `role = 'admin'` es nulo.

### Bloqueo de auto-cambio de `role` en `profiles`: `with check` con subconsulta, no trigger

Se consideraron dos formas de impedir que un usuario cambie su propio
`role` al hacer `update` sobre su propia fila:

1. Un trigger `before update` que compare `new.role` contra `old.role`.
2. Una policy de `update` cuyo `with check` compare `role` contra el valor
   ya almacenado, vía subconsulta a la propia tabla.

Se descarta (1): un trigger `before update` se dispara para **cualquier**
`update` sobre `profiles`, incluido el que se hace a mano desde el SQL
editor/dashboard de Supabase para asignar el primer admin — que es
justamente el mecanismo que este mismo ticket exige mantener disponible.
Se opta por (2), porque las policies de RLS solo aplican a los roles
`authenticated`/`anon` (los que pasan por PostgREST); `postgres` y
`service_role` tienen `bypassrls` y no se ven afectados, así que la
asignación manual del primer admin sigue funcionando sin excepción
especial:

```sql
with check (
  id = auth.uid()
  and role = (select p.role from public.profiles p where p.id = auth.uid())
)
```

La subconsulta ve el valor de `role` previo a este `update` (una sentencia
no ve, dentro de sí misma, las filas que ella misma está modificando —
comportamiento estándar de Postgres para evitar el problema de Halloween),
así que compara siempre contra el valor ya persistido.

### `respuestas_desafio`: sin policy de `update`, aunque el ticket dice "editables"

El ticket agrupa `intentos_nivel`, `respuestas_desafio` y
`progreso_usuario_nivel` bajo "solo visibles y editables por su propio
usuario". Para `intentos_nivel` y `progreso_usuario_nivel` eso implica
`select`+`insert`+`update` (la fila se crea y luego se actualiza a medida
que progresa el intento / se recalcula el mejor resultado). Para
`respuestas_desafio` se aplica solo `select`+`insert`: el propio esquema
(INT-74, comentario D5) la trata como historial inmutable, y el
`unique (intento_id, desafio_id)` ya impide "volver a responder" el mismo
desafío dentro de un intento. Permitir `update` dejaría que un jugador
reescribiera una respuesta ya puntuada (`distancia_km`, `puntos`) después
del hecho, lo cual iría contra ese diseño. `respuestas_desafio` no tiene
columna `usuario_id` propia: la pertenencia se resuelve vía
`intento_id -> intentos_nivel.usuario_id`.

### Sin policies de `delete` en las tablas de progreso

Ninguna de las tareas del ticket menciona borrado, y no hay un flujo de
juego que necesite borrar intentos/respuestas/progreso propios. Se deja
sin policy de `delete` (denegado por defecto), igual que hoy no existe
`delete` en `profiles`.

## Risks / Trade-offs

- **Cambiar la policy de `profiles` es un cambio de comportamiento
  observable** (hoy ningún `update` es posible; después, el dueño puede
  editar `nombre`/`avatar_url`) → aceptado y buscado: es justo lo que pide
  el ticket, y hoy no hay ningún cliente en producción que dependa de que
  `update` esté bloqueado.
- **Un `desafio` sin ninguna asignación en `nivel_desafios` sigue sin ser
  visible para jugadores de todas formas** (ya lo era antes de esta
  change, por diseño D3/D4 de INT-74) → sin cambios de comportamiento
  aquí, solo se menciona porque no hay que "arreglarlo" en RLS.
- **La subconsulta de `is_admin()` y la del `with check` de `profiles`
  añaden un `select` extra por fila evaluada** → coste marginal (tablas
  pequeñas, filtradas por PK); no se optimiza más porque no hay señal de
  que haga falta.

## Migration Plan

Una única migración
`backend/supabase/migrations/<timestamp>_rls_esquema_juego.sql` con, en
orden: `is_admin()`, `enable row level security` + policies de
`tematicas`/`niveles`/`nivel_desafios`, `desafios`, `intentos_nivel`,
`respuestas_desafio`, `progreso_usuario_nivel`, y la nueva policy de
`update` de `profiles` (sustituye nada existente por SQL — es una policy
nueva, no se toca `profiles_select_own`).

Aplicar con `supabase db push --linked` contra el proyecto remoto (mismo
flujo que INT-76), seguido de `supabase db lint --linked`. Verificación con
usuarios de prueba reales (uno `admin`, uno `jugador`/anónimo) vía su
propio JWT — nunca con la clave de servicio, que se salta RLS y no
probaría nada. Rollback: migración inversa que desactiva RLS y borra las
policies/función, solo si hiciera falta revertir (no se prevé necesario).

## Open Questions

Ninguna pendiente: el alcance quedó acotado en las Decisions de arriba.
