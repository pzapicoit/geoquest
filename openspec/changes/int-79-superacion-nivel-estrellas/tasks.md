## 1. Migración: RPC de cierre de intento

- [x] 1.1 Crear migración `superacion_nivel_estrellas` en
      `backend/supabase/migrations/`
- [x] 1.2 Función `cerrar_intento_nivel(p_intento_id uuid) returns
      intentos_nivel` — `security invoker`: resuelve `v_nivel_id` y
      `v_tematica_id` a partir del intento (la RLS ya garantiza que solo se
      puede leer un intento propio)
- [x] 1.3 Agregación de puntaje (D1): `sum(respuestas_desafio.puntos)`
      unido a `nivel_desafios` por `desafio_id` + `nivel_id`, no por
      `intento_id` a solas
- [x] 1.4 Chequeo de completitud (D2): comparar `count(distinct
      desafio_id)` del join contra `count(*)` de `nivel_desafios` del
      nivel; `raise exception` si no coinciden
- [x] 1.5 Cálculo de `superado` (`puntaje >= puntaje_minimo_superar`) y
      `estrellas_obtenidas` (D4: mínimo 1 si `superado`, hasta 3 según
      `umbral_estrella_1/2/3`)
- [x] 1.6 `update intentos_nivel set puntaje_total, superado,
      estrellas_obtenidas where id = p_intento_id`
- [x] 1.7 `grant execute on function cerrar_intento_nivel to authenticated`
      (y `revoke ... from public`)

## 2. Migración: progreso y desbloqueos

- [x] 2.1 Upsert de `progreso_usuario_nivel` (D5) para
      `(auth.uid(), v_nivel_id)` con `greatest()`/`or` sobre
      `mejor_puntaje`/`mejores_estrellas`/`superado`, y `desbloqueado`
      preservando `true` si ya lo estaba
- [x] 2.2 Si `superado`, resolver el siguiente nivel de la misma temática
      (`orden` inmediatamente superior) y upsert de
      `progreso_usuario_nivel` con `desbloqueado = true` para ese nivel, si
      existe
- [x] 2.3 Sumar `mejores_estrellas` de `progreso_usuario_nivel` entre los
      niveles de la temática actual del usuario; si alcanza
      `estrellas_requeridas` de la siguiente temática (D6: siguiente
      `orden` en `tematicas`), upsert de `desbloqueado = true` para el
      nivel `orden = 1` de esa temática

## 3. Verificación manual (casos límite)

- [x] 3.1 `supabase db push` contra el proyecto remoto enlazado
- [x] 3.2 Caso de integridad: cerrar un intento con respuestas a un
      `desafio_id` ajeno al nivel (insertado directamente) → esas
      respuestas no cuentan en el puntaje agregado
- [x] 3.3 Caso de completitud: cerrar un intento al que le falta responder
      un desafío del nivel → falla, no modifica `intentos_nivel` ni
      `progreso_usuario_nivel`
- [x] 3.4 Caso de estrellas: puntaje entre `puntaje_minimo_superar` y
      `umbral_estrella_1` → `superado = true`, `estrellas_obtenidas = 1`
- [x] 3.5 Caso de no mejora: rejugar un nivel ya superado con puntaje/
      estrellas peores → `progreso_usuario_nivel` conserva el mejor
      resultado previo
- [x] 3.6 Caso de mejora: rejugar con puntaje/estrellas mejores →
      `progreso_usuario_nivel` se actualiza al nuevo valor
- [x] 3.7 Caso de desbloqueo de nivel: superar un nivel con siguiente nivel
      en la temática → ese siguiente nivel queda `desbloqueado = true`
- [x] 3.8 Caso de desbloqueo de temática: acumular en
      `progreso_usuario_nivel` las estrellas requeridas por la siguiente
      temática → el primer nivel de esa temática queda `desbloqueado =
      true`
- [x] 3.9 Caso de seguridad: intentar cerrar un `intento_id` que no
      pertenece al usuario autenticado → no devuelve fila / falla, sin
      modificar nada
- [x] 3.10 Caso de idempotencia: cerrar el mismo intento dos veces →
      segundo cierre no cambia el resultado ya escrito

## 4. Fixes de la revisión adversarial

- [x] 4.1 `raise exception` si el `update intentos_nivel` no afecta
      ninguna fila (defensa ante que el intento desaparezca entre la
      lectura inicial y el update)
- [x] 4.2 D7: `pg_advisory_xact_lock` por `(auth.uid(), tematica_id)` antes
      de sumar `mejores_estrellas` y decidir el desbloqueo de la siguiente
      temática, para evitar el "lost update" bajo `READ COMMITTED` cuando
      dos niveles de la misma temática se cierran concurrentemente
- [x] 4.3 Regresión: repetidos los 9 casos de la sección 3 tras el fix, sin
      cambios de comportamiento
- [x] 4.4 Intento de reproducción empírica de la carrera con dos cierres
      concurrentes reales — no se consiguió forzar solapamiento genuino
      (el pool de conexiones de PostgREST y el modo de `supabase db query`
      serializan las llamadas concurrentes en este entorno); el fix se
      apoya en el análisis de `READ COMMITTED` del revisor adversarial y
      en la revisión de código, no en una reproducción determinista
