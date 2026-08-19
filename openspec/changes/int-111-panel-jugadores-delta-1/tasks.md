## 1. Backend: deduplicación y restricción de alias único

- [x] 1.1 Escribir la consulta de dedupe genérica (`row_number() over (partition by nombre order by u.created_at)` sobre `profiles`/`auth.users`, `role = 'jugador'`) y usarla para renombrar in-place a todos los perfiles menos el más antiguo de cada grupo duplicado, con sufijo `' (' || n || ')'` truncando la base a 16 caracteres si hace falta.
- [x] 1.2 Añadir la restricción de unicidad tras el dedupe — implementado como índice único parcial (`create unique index ... where role = 'jugador'`) en vez de un `constraint unique` de tabla, porque el requisito es "sin duplicados entre jugadores" y un constraint no admite `WHERE` (ver D1 de design.md).
- [x] 1.3 Reescribir `handle_new_user()` con bucle acotado (hasta 30 intentos) que compruebe `not exists (select 1 from profiles where nombre = candidato)` antes de insertar; si se agotan los intentos, añadir un fragmento de `new.id` al candidato para garantizar unicidad.
- [x] 1.4 Verificar manualmente contra el remoto: los 6 "Zapi" quedan como "Zapi"/"Zapi (2)"/.../"Zapi (6)" según su `created_at`; un `insert` directo de prueba en `auth.users` (o una alta anónima real) no falla aunque se fuerce una colisión del candidato aleatorio.

## 2. Backend: eliminación de jugador y auditoría

- [x] 2.1 Crear tabla `auditoria_eliminacion_jugador` (`id`, `admin_id references profiles(id)`, `jugador_id uuid` sin FK, `alias_jugador text`, `creado_en timestamptz default now()`) con RLS: solo `select` para `is_admin()`.
- [x] 2.2 Crear RPC `eliminar_jugador(p_jugador_id uuid)` (`security definer`, gate `is_admin()`) que valide `role = 'jugador'`, inserte la fila de auditoría con el alias vigente, y borre `auth.users` del jugador (cascada real a `profiles` y de ahí a todo su progreso/historial).
- [x] 2.3 Revocar `execute` a `public` y concederlo solo a `authenticated`.
- [x] 2.4 Verificar manualmente contra el remoto: eliminación exitosa de un jugador de prueba con progreso; intento sobre un admin (rechazado); llamada como no-admin (rechazada); la fila de auditoría persiste y es legible tras la eliminación.
- [x] 2.5 Aplicar la migración completa (1.x + 2.x) al remoto con `supabase db push` y `supabase db lint --linked`.

## 3. App: distinguir el error de alias en uso

- [x] 3.1 En `app/lib/services/profile_gateway.dart`, capturar `PostgrestException` con `code == '23505'` y relanzar como una excepción propia (p. ej. `AliasEnUsoException`).
- [x] 3.2 En `app/lib/screens/username_screen.dart`, capturar `AliasEnUsoException` por separado y mostrar "Ese apodo ya está en uso, prueba con otro"; mantener el mensaje genérico actual para el resto de errores.
- [x] 3.3 Tests: `profile_gateway_test.dart` (o equivalente) cubriendo el mapeo de la excepción; test de `username_screen` cubriendo el mensaje específico frente al genérico.

## 4. Panel: acción de eliminar jugador

- [ ] 4.1 Añadir `eliminarJugador(jugadorId)` a `panel/src/lib/jugadores.ts` (llama a `eliminar_jugador`).
- [ ] 4.2 Test de `eliminarJugador` en `jugadores.test.ts` (invocación correcta, propagación de error).
- [ ] 4.3 Añadir la acción "Eliminar jugador" por fila en `Jugadores.tsx` y su modal de confirmación (mismo patrón de escritura de alias exacto que el de reinicio, texto propio que deja claro que se borra la cuenta entera).
- [ ] 4.4 Al confirmar, invocar `eliminarJugador`, quitar al jugador de la lista local (no solo poner sus datos a cero) y mostrar confirmación visual del resultado, incluyendo el caso de error.
- [ ] 4.5 Tests en `Jugadores.test.tsx`: botón deshabilitado hasta que el alias coincide, invocación de la RPC, jugador desaparece de la tabla tras eliminar con éxito, manejo de error.
- [ ] 4.6 Correr la suite completa del panel (`vitest run`, `--coverage`, `eslint`, `tsc --noEmit`, `prettier --check`) y verificar que sigue en línea con el resto del panel.
