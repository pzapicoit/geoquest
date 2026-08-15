## 1. Migración SQL

- [x] 1.1 Crear migración
      `backend/supabase/migrations/<timestamp>_rls_esquema_juego.sql`
- [x] 1.2 Función `is_admin()` (`language sql`, `stable`,
      `security invoker`, `set search_path = public`)
- [x] 1.3 `enable row level security` + policy `select` (`to authenticated
      using (true)`) en `tematicas`, `niveles` y `nivel_desafios`
- [x] 1.4 Policies `insert`/`update`/`delete` (`to authenticated using
      (is_admin()) with check (is_admin())`) en `tematicas`, `niveles` y
      `nivel_desafios`
- [x] 1.5 `enable row level security` en `desafios` + policy `select`
      restringida a `is_admin()` (sin policy pública de lectura) +
      policies `insert`/`update`/`delete` restringidas a `is_admin()`
- [x] 1.6 `enable row level security` en `intentos_nivel` + policies
      `select`/`insert`/`update` con `usuario_id = auth.uid()` (`using` y
      `with check` según corresponda)
- [x] 1.7 `enable row level security` en `respuestas_desafio` + policies
      `select`/`insert` (sin `update`) verificando pertenencia vía
      `exists (select 1 from intentos_nivel where id = intento_id and
      usuario_id = auth.uid())`
- [x] 1.8 `enable row level security` en `progreso_usuario_nivel` +
      policies `select`/`insert`/`update` con `usuario_id = auth.uid()`
- [x] 1.9 Policy `update` en `profiles` (`to authenticated using (id =
      auth.uid()) with check (id = auth.uid() and role = (select p.role
      from public.profiles p where p.id = auth.uid()))`)
- [x] 1.10 Comentarios de cabecera en la migración referenciando INT-77 y
       las decisiones de `design.md` (por qué `desafios` sí permite
       `select` a `is_admin()`, por qué `respuestas_desafio` no tiene
       `update`, por qué el bloqueo de `role` es `with check` y no
       trigger)

## 2. Aplicar y verificar en el proyecto remoto

- [x] 2.1 `supabase db push --linked` contra el proyecto remoto
- [x] 2.2 `supabase db lint --linked`
- [x] 2.3 Crear dos usuarios de prueba reales: uno promovido a
      `profiles.role = 'admin'` (vía clave de servicio/SQL) y uno jugador
      con sesión anónima real (`profiles.role = 'jugador'` por defecto)
- [x] 2.4 Confirmar, con el JWT propio de cada usuario, que ambos pueden
      leer `tematicas`, `niveles` y `nivel_desafios`
- [x] 2.5 Confirmar que el admin puede `insert`/`update`/`delete` en
      `tematicas`, `niveles`, `desafios` y `nivel_desafios`, y que puede
      leer `desafios` directamente (incluye `lat_real`/`lng_real`/
      `nombre_lugar`)
- [x] 2.6 Confirmar que el jugador NO puede `insert`/`update`/`delete` en
      `tematicas`, `niveles`, `desafios` ni `nivel_desafios`, y que un
      `select` directo sobre `desafios` no devuelve filas
- [x] 2.7 Confirmar que el jugador puede crear su propio `intento_nivel`,
      insertar `respuestas_desafio` para ese intento, y crear/actualizar su
      propia fila de `progreso_usuario_nivel`
- [x] 2.8 Confirmar que el jugador NO puede leer ni crear
      `intentos_nivel`/`respuestas_desafio`/`progreso_usuario_nivel` a
      nombre del otro usuario de prueba
- [x] 2.9 Confirmar que un `update` del propio jugador sobre una
      `respuesta_desafio` ya insertada se rechaza (sin policy de `update`)
- [x] 2.10 Confirmar que ambos usuarios pueden actualizar su propio
      `nombre`/`avatar_url` en `profiles`, y que un intento de cambiar su
      propio `role` (incluyendo el jugador intentando pasar a `admin`) se
      rechaza sin afectar ninguna columna — se rechaza con un error 403
      (`42501`, viola el `with check`) porque el jugador sí puede ver su
      propia fila (`using` pasa); no es el filtrado silencioso de 0 filas
      que sí se ve en 2.6/2.8 cuando falla el `using`
- [x] 2.11 Confirmar que la asignación manual de `role = 'admin'` desde el
      SQL editor del dashboard (o la clave de servicio) sigue funcionando
      pese a la nueva policy de `update` de `profiles`
- [x] 2.12 Repetir 2.4-2.10 con una segunda sesión anónima para confirmar
      que el comportamiento es idéntico entre sesión anónima y cuenta
      "vinculada" (incluida en la comparación un usuario de prueba
      creado directamente con email/contraseña, mismo trato que una cuenta
      vinculada porque ambas son simplemente una fila con `auth.uid()`
      propio)
- [x] 2.13 Borrar los usuarios de prueba creados para esta verificación

## 3. Primer admin real

- [x] 3.1 Asignar `role = 'admin'` manualmente, vía SQL/dashboard de
      Supabase, a la cuenta real que administrará el contenido (paso
      operativo, no versionado en una migración) — ya existía
      `admin-test@geoquest.dev` con `role = 'admin'` (de la verificación de
      INT-76); se adopta como el primer admin, sin crear una cuenta nueva

## 4. Documentación

- [x] 4.1 Actualizar `.devplugin/architecture.md`: quitar "sin RLS en
      tablas del juego (INT-77)" de la fila de `backend/` y reflejar que
      el esquema completo ya tiene RLS
