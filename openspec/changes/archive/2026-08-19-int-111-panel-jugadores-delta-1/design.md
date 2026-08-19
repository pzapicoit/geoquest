## Context

INT-111 (archivado) dejó el listado de jugadores y el reinicio de progreso funcionando contra datos reales del proyecto Supabase remoto. Al probarlo, aparecieron dos huecos: no hay forma de borrar del todo a un jugador, y `profiles.nombre` no tiene ninguna restricción de unicidad (hay 6 perfiles con alias "Zapi" ahora mismo). El alta anónima (`handle_new_user()`, INT-75) asigna un alias por defecto `'Jugador' || lpad(random 0-9999, 4, '0')` — 10 000 combinaciones — sin comprobar colisión, y el cambio de apodo desde la app (`profile_gateway.dart`) hace un `update` directo sobre `profiles` sin ninguna validación de unicidad ni manejo de error específico (`username_screen.dart` atrapa cualquier excepción con `catch (_)` y siempre muestra el mismo mensaje de "comprueba tu conexión").

## Goals / Non-Goals

**Goals:**
- Eliminar por completo la cuenta de un jugador desde el panel, con la misma calidad de confirmación/auditoría que ya tiene el reinicio.
- Garantizar `profiles.nombre` único a nivel de base de datos, sin dejar huecos por los que un jugador nuevo o un cambio de apodo puedan colar un duplicado.
- No romper el alta anónima ni el testing local ya hecho: los datos duplicados existentes se normalizan, no se bloquea el despliegue.

**Non-Goals:**
- Papelera o soft-delete de jugadores: "eliminar" es definitivo, igual que "reiniciar" ya lo era para el progreso — no se pide lo contrario.
- Pantalla de edición de alias en el panel: sigue sin pedirse: el admin no renombra jugadores, solo elimina o reinicia.
- Cambiar la validación de longitud/charset del apodo en la app (min 3 / max 16, sin restricción de charset): no se toca, solo se le añade la comprobación de unicidad por debajo.

## Decisions

**D1 — Deduplicación genérica por orden de creación, no una lista de ids hardcodeada.**
Para cada grupo de `profiles.nombre` duplicado (`role = 'jugador'`), se ordena por `auth.users.created_at` y se deja intacto el más antiguo; a los siguientes se les añade un sufijo `' (' || n || ')'` (n = 2, 3, ...). Generalizado con una consulta sobre `row_number() over (partition by nombre order by u.created_at)`, no una migración de datos con UUIDs fijos — así la migración sigue siendo correcta si aparecen más duplicados entre que se escribe y se aplica.

**D2 — El sufijo respeta el límite de 16 caracteres que ya impone la app (INT-89).**
Si `length(nombre) + length(sufijo) > 16`, se trunca la parte base del nombre para que el resultado final quepa en 16 caracteres. Evita que la migración produzca un alias que la propia app rechazaría si el jugador intentara volver a guardarlo tal cual.

**D3 — `handle_new_user()` reintenta en vez de fallar.**
El generador de alias por defecto pasa a un bucle acotado (hasta 30 intentos) que prueba `'Jugador' || lpad(random 4 dígitos, 4, '0')` y comprueba `not exists (select 1 from profiles where nombre = candidato)` antes de insertar. Si los 30 intentos se agotan (extremadamente improbable con miles de jugadores sobre 10 000 combinaciones), el último candidato incorpora un fragmento del `uuid` del propio `new.id` para garantizar unicidad sin bucle infinito. Sin este cambio, el `UNIQUE` de D1 convertiría cualquier colisión de alta anónima en un alta fallida — una regresión sobre el flujo "sin fricción" que INT-75 dejó documentado como objetivo explícito.

**D4 — `eliminar_jugador()` borra `auth.users` directamente por SQL, no vía la API de administración de Supabase.**
Comprobado contra el proyecto remoto: el rol `postgres` (dueño de las funciones creadas por migración, igual que `jugadores_listado`/`reiniciar_progreso_jugador`) ya tiene `DELETE` sobre `auth.users`. Una función `security definer` puede hacer `delete from auth.users where id = p_jugador_id`, que en cascada (FK ya existente) borra `profiles`, y desde ahí `progreso_usuario_nivel`/`intentos_nivel`/`respuestas_desafio`. No hace falta la clave de servicio ni un endpoint aparte — coherente con "no hay backend custom" de `architecture.md`.

**D5 — Tabla de auditoría propia (`auditoria_eliminacion_jugador`), no reutilizar `auditoria_reinicio_progreso`.**
Mismo motivo que separar `reiniciar_progreso_jugador` de un hipotético "reset con modos": alterar la tabla/RPC de auditoría del reinicio ya archivado y en producción para añadirle un discriminador de tipo de acción es más riesgo (migración de esquema sobre una tabla ya en uso) que crear una segunda tabla con la misma forma (`admin_id`, `jugador_id` sin FK, `alias_jugador` snapshot, `creado_en`) y la misma policy de solo-lectura-admin.

**D6 — Confirmación por alias igual que el reinicio, texto propio.**
Mismo componente de interacción (escribir el alias exacto para habilitar el botón), pero el copy dice explícitamente que se borra la cuenta entera (no solo el progreso) y que el jugador no podrá volver a entrar con ese acceso.

**D7 — La app distingue el error de unicidad por código Postgres (`23505`), no por texto del mensaje.**
`profile_gateway.dart` inspecciona el `code` de la `PostgrestException` (`23505` = `unique_violation`) y lanza un tipo de excepción propio (`AliasEnUsoException`) en ese caso; `username_screen.dart` lo captura por separado del resto y muestra "Ese apodo ya está en uso, prueba con otro" en vez del mensaje genérico de conexión.

## Risks / Trade-offs

- [Riesgo] La eliminación es más destructiva que el reinicio (se pierde también la cuenta/alias) y un admin podría confundirla con él en una tabla larga → Mitigación: confirmación por alias exacto (D6) con copy explícito distinto al del reinicio, e icono/color de acción distinto en la fila.
- [Riesgo] El bucle de reintento de `handle_new_user()` (D3) añade una comprobación extra en el camino crítico del alta anónima → Mitigación: el espacio de 10 000 combinaciones hace que la mayoría de altas acierten al primer intento; el bucle solo itera de más cuando ya hay colisión real.
- [Riesgo] Truncar el alias en la deduplicación (D2) podría producir dos alias truncados iguales entre sí en casos muy extremos (nombres ya de 16 caracteres con muchos duplicados) → Mitigación: el sufijo numerado sigue siendo parte del resultado final incluso truncando la base, así que dos filas del mismo grupo nunca truncan al mismo texto (los `n` del sufijo son distintos por construcción de `row_number()`).
- [Riesgo] Cambiar el mensaje de error de la app toca un flujo ya en producción (INT-89) → Mitigación: cambio aislado y aditivo (un tipo de excepción nuevo, un mensaje nuevo para ese caso concreto); el resto de errores siguen mostrando el mensaje genérico igual que hoy.

## Migration Plan

Una migración SQL nueva: dedupe de datos → `UNIQUE` en `profiles.nombre` → `create or replace function handle_new_user()` con el reintento → tabla + RLS de `auditoria_eliminacion_jugador` → RPC `eliminar_jugador`. Se aplica con `supabase db push` igual que el resto. Sin rollback de los renombrados (son datos de prueba/dev, decisión ya tomada con el usuario); rollback de esquema, si hiciera falta, es un `drop constraint`/`drop function`/`drop table` estándar.
