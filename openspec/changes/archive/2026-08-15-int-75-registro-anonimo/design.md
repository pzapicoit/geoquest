## Context

INT-73 dejó el entorno Supabase versionado en `backend/supabase/` y el cliente
inicializado en la app (`app/lib/main.dart`, `Supabase.initialize`). INT-74
dejó el esquema de juego, incluida la tabla `profiles` (`id` = `auth.users.id`,
`role` enum `admin`/`jugador`), explícitamente **sin** trigger de creación de
perfil — ese trigger es el objeto de este cambio. No existe todavía ningún
mecanismo de autenticación configurado ni en Supabase Auth ni en la app.

Dos consumidores muy distintos comparten el mismo backend de Auth:
- La **app de jugador** (Flutter), que necesita fricción cero.
- El **panel de administración** (uso interno), que necesita login clásico.

## Goals / Non-Goals

**Goals:**
- Alta anónima automática y transparente para el jugador, con sesión
  persistente en el dispositivo.
- Perfil (`profiles`) creado automáticamente para toda alta, anónima o no,
  vinculado al UUID del dispositivo que la originó.
- Camino de vinculación de identidad (Google/Apple) que preserve el `user id`
  y por tanto el progreso.
- Login email/contraseña funcional para cuentas de administrador.

**Non-Goals:**
- Pantallas del panel de administración (INT-80) — este cambio cubre el
  mecanismo de auth, no la UI.
- Políticas de RLS por rol (INT-77) — quién puede leer/escribir qué tabla se
  decide en esa tarea, no en esta.
- Proveedores OAuth adicionales más allá de Google/Apple.
- Recuperación de contraseña para admins (se puede añadir después con el
  flujo estándar de Supabase Auth si hace falta).

## Decisions

### D1: Habilitar "Anonymous Sign-ins" en Supabase Auth
Se activa el proveedor anónimo nativo de Supabase (`signInAnonymously`) en
lugar de generar credenciales aleatorias a mano. Es la opción soportada
oficialmente por `supabase_flutter` y por `linkIdentity`, y no requiere
backend propio.

### D2: Persistencia de sesión vía el almacenamiento por defecto de `supabase_flutter`
`Supabase.initialize` en v2 ya persiste la sesión en disco (mediante su
`LocalStorage` por defecto) y la restaura sola en el arranque. No hace falta
código adicional de persistencia manual: basta con no cerrar la sesión y
comprobar `Supabase.instance.client.auth.currentSession` antes de decidir si
hace falta `signInAnonymously()`. Alternativa descartada: guardar el JWT a
mano en `flutter_secure_storage` — duplica lo que ya hace el SDK y añade una
fuente de desincronización.

### D3: Trigger `on auth.users insert` para crear el `profile`
Un trigger de Postgres (`after insert on auth.users`) crea la fila en
`profiles` para toda alta nueva, anónima o no, en lugar de que la app lo haga
desde el cliente. Así el perfil existe siempre, incluso si la app se cierra
justo después de crear la sesión, y el nombre por defecto ("JugadorNNNN") se
genera en un único lugar. Se distingue alta anónima de alta con
email/contraseña por `new.is_anonymous` (columna nativa de `auth.users`); las
cuentas no anónimas creadas por este camino reciben igualmente rol `jugador`
por defecto — las cuentas `admin` se dan de alta aparte (ver D5).

### D6: UUID de dispositivo como identificador provisional en `profiles`
Se añade la columna `profiles.device_id uuid`. La app genera un UUID v4 en el
primer arranque (paquete `uuid`), lo persiste localmente (mismo mecanismo que
la sesión, no hace falta uno nuevo) y lo pasa como `data` al llamar a
`signInAnonymously(data: {'device_id': <uuid>})`; Supabase guarda ese `data`
en `raw_user_meta_data` de `auth.users`, y `handle_new_user()` (D3) lo lee de
ahí para rellenar `profiles.device_id` en el mismo insert. Es un identificador
**provisional**: sirve mientras el perfil no tiene identidad vinculada
(Google/Apple); no pretende sobrevivir a una reinstalación ni sustituir a
`linkIdentity` como mecanismo de recuperación de cuenta a largo plazo.
Alternativa descartada: usar un identificador de hardware (`device_info_plus`)
en vez de un UUID generado por la app — se descarta porque varía por
plataforma (Android Advertising ID deprecado, `identifierForVendor` de iOS
cambia entre instalaciones) y añade una dependencia nativa que no aporta nada
que un UUID propio no dé ya para este caso de uso.

### D4: Vinculación con `linkIdentity`
Se usa `supabase.auth.linkIdentity()` sobre la sesión anónima activa para
añadir la identidad Google/Apple al mismo usuario, en vez de crear una cuenta
nueva y migrar datos. Esto conserva el mismo `auth.users.id` y por tanto todo
lo que cuelga de él por FK (`intentos_nivel`, `progreso`, etc.) sin migración
de datos.

### D5: Cuentas de administrador como alta separada, no autoprovisión
Las cuentas `admin` no se crean por un flujo de autoservicio: se dan de alta
manualmente (dashboard de Supabase o script) y se marca `profiles.role =
'admin'` explícitamente. El login del panel usa
`signInWithPassword(email, password)` estándar de Supabase Auth. No hay
registro público de administradores.

## Risks / Trade-offs

- **[Riesgo] Cuentas anónimas huérfanas si el usuario nunca vincula cuenta.**
  → Aceptado por ahora: Supabase permite limpiarlas más adelante con un job
  si hiciera falta; no bloquea esta tarea.
- **[Riesgo] `linkIdentity` falla si el email de Google/Apple ya está en uso
  por otra cuenta.** → Cubierto explícitamente en la spec
  (`player-anonymous-auth`): falla con mensaje claro y la sesión anónima
  original queda intacta.
- **[Trade-off] Confiar en el almacenamiento por defecto de `supabase_flutter`
  en vez de gestionar la sesión a mano** → Menos control fino, pero evita
  divergencias entre el estado del SDK y un storage paralelo; es el patrón
  recomendado por la librería.
- **[Riesgo] El UUID de dispositivo no sobrevive a una reinstalación ni
  identifica de forma fiable "el mismo dispositivo" en todos los casos
  (restauración de backup, etc.).** → Aceptado explícitamente: es un
  identificador provisional (D6), no el mecanismo de recuperación de cuenta;
  ese rol lo cumple `linkIdentity`.

## Migration Plan

1. Migración SQL: habilitar proveedor anónimo (config de Auth, no SQL) +
   columna `profiles.device_id` + trigger `handle_new_user` sobre
   `auth.users` (lee nombre por defecto y `device_id` de `raw_user_meta_data`).
2. App: en el arranque, si no hay sesión (`currentSession == null`), generar
   o leer el UUID de dispositivo persistido y llamar a
   `signInAnonymously(data: {'device_id': uuid})` antes de navegar a la home.
3. Sin datos existentes que migrar (no hay usuarios todavía en producción).
4. Rollback: deshabilitar el proveedor anónimo en el dashboard de Auth y
   revertir la migración del trigger; no afecta a `game-data-model`.
