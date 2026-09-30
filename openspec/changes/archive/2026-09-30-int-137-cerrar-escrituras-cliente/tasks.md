## 1. Verificación previa

- [x] 1.1 Buscar en `app/lib`, `panel/src` y `backend/supabase/functions` cualquier `insert`/`update`/`upsert`/`delete`/`from(...)` sobre `intentos_nivel`, `intento_desafios`, `respuestas_desafio` y `progreso_usuario_nivel`; confirmar que solo hay `rpc` (o anotar y tratar la excepción)
- [x] 1.2 Enumerar las funciones y triggers que escriben en esas cuatro tablas en su última definición y su modo (`security definer`/`invoker`); confirmar que solo `iniciar_intento_parada` y `cerrar_intento_parada` son `invoker`
- [x] 1.3 Comprobar los `grant`/`revoke execute` vigentes de esas dos funciones para que `create or replace` no los altere

## 2. Migración SQL

- [x] 2.1 Crear `backend/supabase/migrations/20260930120000_cierra_escrituras_cliente_tablas_juego.sql` con los `drop policy` de las políticas `insert_own`/`update_own` de las cuatro tablas
- [x] 2.2 Añadir `revoke insert, update, delete, truncate` sobre las cuatro tablas a `anon` y `authenticated`
- [x] 2.3 Redefinir `iniciar_intento_parada` como `security definer` con `set search_path = public`, copiando la última definición (`20260820200000`) sin otros cambios
- [x] 2.4 Redefinir `cerrar_intento_parada` como `security definer` con `set search_path = public` (última definición `20260819170000`), añadiendo `ni.usuario_id = auth.uid()` al localizar el intento
- [x] 2.5 Modificar `responder_desafio` (última definición `20260820225359`) para exigir, antes de leer `desafios`, que el desafío esté en `intento_desafios` del intento y sin respuesta previa, con el mismo error para un desafío inexistente y uno de otro intento
- [x] 2.6 Añadir al trigger `respuestas_desafio_calcular_antes_de_insertar` (última definición `20260818122000`) el rechazo si el desafío no pertenece al intento
- [x] 2.7 Incluir en la migración la comprobación de que `revoke execute ... from public` y `grant execute ... to authenticated` siguen vigentes para las funciones redefinidas

## 3. Test SQL de RLS y antitrampas

- [x] 3.1 Crear `backend/supabase/tests/test_rls_tablas_juego.sql` en transacción con rollback: dos usuarios de prueba, `request.jwt.claims` y `set local role authenticated`
- [x] 3.2 Escenarios de escritura directa rechazada: `update`/`insert` en `progreso_usuario_nivel`, `update` de `intentos_nivel` (incluido `comodin_usado = null`), `insert` en `intentos_nivel`, `respuestas_desafio` e `intento_desafios`
- [x] 3.3 Escenario de flujo completo por RPC (`iniciar_intento_parada`, `marcar_desafio_mostrado`, `responder_desafio`, `cerrar_intento_parada`) y lectura posterior del progreso y del resultado del intento
- [x] 3.4 Escenario de intento ajeno: `cerrar_intento_parada` y `responder_desafio` con el `intento_id` de otro usuario fallan sin cambiar filas
- [x] 3.5 Escenario de desafío de otro intento: `responder_desafio(B, desafio_de_A, ...)` falla, no inserta y no devuelve `lat_real`/`lng_real`/`ciudad`; mismo error que para un `desafio_id` inexistente
- [x] 3.6 Escenario de segunda respuesta al mismo desafío rechazada sin volver a revelar la ubicación

## 4. Verificación local

- [x] 4.1 Aplicar la migración (no hay base local: se aplicó al remoto con `supabase db push`, con aprobación) y ejecutar `test_rls_tablas_juego.sql` hasta que pase; estado verificado además por catálogo (sin policies ni privilegios de escritura, funciones `security definer`, sin usuarios de prueba residuales)
- [x] 4.2 Ejecutar los tests SQL existentes para descartar regresiones: `test_clasificacion.sql` fallaba porque insertaba respuestas de desafíos fuera de `intento_desafios` (lo que ahora rechaza el trigger); el fixture crea ahora las filas de selección y los valores esperados no cambian
- [x] 4.3 Ejecutar `flutter analyze` y `flutter test` en `app/`, y `npm run test` y `npm run lint` en `panel/`, para confirmar que nada depende de las políticas eliminadas
- [x] 4.4 Si no hay base local disponible, dejar documentado qué queda sin ejecutar y el comando exacto para hacerlo contra el remoto

## 5. Documentación y cierre

- [x] 5.1 Actualizar `backend/README.md` (reparto de claves y modelo de seguridad) indicando que las tablas de juego solo se escriben vía RPC
- [x] 5.2 Preparar, sin ejecutarlo, el comando de aplicación al remoto (`supabase db push`) y el rollback (`openspec/changes/archive/2026-09-30-int-137-cerrar-escrituras-cliente/rollback.sql`, fuera de `migrations/`); aplicar al remoto solo con aprobación explícita
