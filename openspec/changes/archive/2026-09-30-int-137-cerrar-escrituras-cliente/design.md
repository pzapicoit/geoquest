## Context

GeoQuest no tiene backend propio: la app y el panel hablan con Supabase usando la clave publicable, así que RLS y los privilegios de tabla son la única frontera de seguridad. Las tablas de juego (`intentos_nivel`, `intento_desafios`, `respuestas_desafio`, `progreso_usuario_nivel`) tienen políticas `insert_own`/`update_own` (`20260815112251_rls_esquema_juego.sql`, `20260817224433_persistir_desafios_intento.sql`) que ninguna migración posterior retira. Eran necesarias cuando el cliente escribía directo, y desde entonces dos RPC (`iniciar_intento_parada`, `cerrar_intento_parada`) siguen siendo `security invoker` y dependen de ellas. El resto de RPC de escritura (`responder_desafio`, `marcar_desafio_mostrado`, `usar_comodin`, `reiniciar_progreso_jugador`) ya son `security definer`.

Estado verificado leyendo el código:

- La app (`app/lib`) y el panel (`panel/src`) no hacen `from('<tabla de juego>')` ni insert/update sobre estas tablas; escriben solo vía `rpc`. El único `update` del cliente es `profiles.nombre`.
- `responder_desafio` (`20260820225359_ciudad_desafio_revelado.sql:44`) comprueba la pertenencia del intento pero lee `lat_real`/`lng_real`/`ciudad` de `desafios` para cualquier `p_desafio_id`, antes de insertar. Si la inserción falla por la unicidad (intento, desafío) la excepción revierte la función, pero con un desafío de otro intento la inserción no falla y se devuelve el revelado.
- El trigger `respuestas_desafio_calcular_antes_de_insertar` también acepta desafíos que no son del intento, y un `insert` directo devuelve `distancia_km`, con lo que se puede triangular la coordenada real.

## Goals / Non-Goals

**Goals:**

- Que ningún rol de cliente pueda escribir en las cuatro tablas de juego fuera de las RPC.
- Que `responder_desafio` no revele nada de un desafío que no pertenece al intento.
- Dejar un test SQL repetible de RLS y antitrampas.

**Non-Goals:**

- Tope diario de comodines por anuncio (INT-138) ni reloj del servidor (INT-139).
- Restringir columnas de `profiles` o el acceso de `anon` a `estado_apodo` (incidencias aparte).
- Cambios en app o panel, salvo que la verificación encuentre una escritura directa que hoy se nos escapa.

## Decisions

**D1. Eliminar las políticas de escritura y además revocar privilegios.** Se hace `drop policy` de las ocho políticas `insert_own`/`update_own` y `revoke insert, update, delete, truncate` sobre las cuatro tablas a `anon` y `authenticated`. La revocación es la red de seguridad: si una política futura se añade por error, sin el privilegio de tabla no sirve de nada. Alternativa descartada: dejar las políticas y limitar columnas con `grant update (col)`; obliga a razonar columna a columna y mantener la lista cuando el esquema crece.

**D2. `iniciar_intento_parada` y `cerrar_intento_parada` pasan a `security definer` con `set search_path = public`.** Sin las políticas dejan de poder escribir. Se usa `create or replace` (conserva los `grant`). Como `security definer` ejecuta como propietario y se salta RLS, hay que sustituir explícitamente el filtro que hacía RLS:

- `iniciar_intento_parada` ya deriva el usuario de `auth.uid()` y no acepta parámetro de usuario; no cambia de lógica.
- `cerrar_intento_parada` hoy localiza el intento con `where ni.id = p_intento_id` confiando en que RLS filtre. Se añade `and ni.usuario_id = auth.uid()`, con el mismo mensaje de error actual («no existe o no pertenece al usuario autenticado»). Sin esto, pasar a definer permitiría cerrar, y por tanto puntuar, el intento de otro usuario. Es el punto más delicado del cambio.

Alternativa descartada: mantener `security invoker` y una política `update` muy estrecha; sigue dejando al cliente escribir filas de progreso.

**D3. Comprobación de pertenencia dentro de `responder_desafio`, antes de leer `desafios`.** Tras validar el intento, se exige `exists (select 1 from intento_desafios where intento_id = p_intento_id and desafio_id = p_desafio_id)` y que no exista respuesta previa para ese par. Un desafío inexistente y uno de otro intento fallan por la misma comprobación y con el mismo mensaje («El desafio % no pertenece al intento %»), para que la función no sirva de oráculo de existencia de ids. No se exige que sea «el siguiente por `orden`»: eso pertenece al rediseño del reloj (INT-139) y cambiaría el comportamiento de la app (responder desafíos en otro orden); se anota como pregunta abierta.

**D4. El trigger repite la comprobación.** `respuestas_desafio_calcular_antes_de_insertar` ya lee `intento_desafios`; se le añade el rechazo si no hay fila para (intento, desafío). Es defensa en profundidad por si en el futuro otra ruta inserta en `respuestas_desafio`.

**D5. Una sola migración nueva, con las funciones completas.** `backend/supabase/migrations/20260930120000_cierra_escrituras_cliente_tablas_juego.sql` contiene los `drop policy`, los `revoke`, y las tres funciones y el trigger copiados desde su última definición (`responder_desafio`: `20260820225359`; `iniciar_intento_parada`: `20260820200000`; `cerrar_intento_parada`: `20260819170000`; trigger: `20260818122000`). Las migraciones antiguas no se tocan.

**D6. Test SQL autónomo, en transacción con rollback.** Sigue el patrón de `backend/supabase/tests/` (script sin pgTAP), pero dentro de `begin … rollback`: crea dos usuarios en `auth.users`, fija `request.jwt.claims` y `set local role authenticated`, y comprueba con `do $$ … $$` y `exception when others`. Cubre los escenarios de las especificaciones: escrituras directas rechazadas en las cuatro tablas, flujo completo por RPC, cierre de intento ajeno, y respuesta a un desafío de otro intento sin fuga de datos.

## Risks / Trade-offs

- **[Una función de escritura que se nos escape y siga dependiendo de las políticas]** → Se enumeraron todas las sentencias `insert/update/delete` sobre las cuatro tablas en las migraciones; las vigentes son las RPC ya citadas. El test de flujo completo por RPC con el rol `authenticated` lo confirma antes de aplicar al remoto.
- **[Pasar a `security definer` sin filtro de propietario]** → D2: comprobación explícita de `auth.uid()` en `cerrar_intento_parada`, con escenario de prueba de intento ajeno.
- **[El remoto puede no coincidir con las migraciones locales]** → No se verifica desde aquí; antes de aplicar se compara con `supabase db diff`/listado de políticas del proyecto remoto.
- **[Clientes antiguos en circulación]** → La app y la web desplegada solo usan RPC, así que no deberían romperse. Se confirma con la búsqueda en el código y con el test de flujo.
- **[Las vistas de clasificación y `camino_jugador` leen `progreso_usuario_nivel`]** → Solo necesitan `select`, que se conserva; se comprueba en el test de flujo.

## Migration Plan

1. Verificar en local (Supabase local o base temporal) la migración y el test SQL.
2. Ejecutar las suites existentes (`flutter test`, tests SQL de puntaje y clasificación) para detectar regresiones.
3. Con aprobación explícita, aplicar la migración al proyecto remoto de Supabase y ejecutar allí el test de solo lectura equivalente (comprobar políticas y privilegios).
4. Rollback: migración inversa que restaura las políticas y privilegios y devuelve las dos funciones a `security invoker`. No hay pérdida de datos.

## Open Questions

- ¿Debe `responder_desafio` exigir además el orden de `intento_desafios.orden`? Se difiere a INT-139, donde se decide qué desafío es «el actual» desde el servidor.
- ¿Existen en el remoto políticas o privilegios añadidos a mano que no estén en las migraciones? No se puede comprobar sin acceso al proyecto.
