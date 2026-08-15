## 1. Backend: `actividad_reciente()`

- [x] 1.1 Confirmar contra el proyecto remoto que `auth.users` es legible
      desde una función `security definer` propiedad de `postgres` (mismo
      supuesto que `handle_new_user`, INT-75) antes de escribir la migración.
- [x] 1.2 Migración `backend/supabase/migrations/<timestamp>_actividad_reciente.sql`
      con `actividad_reciente(p_limite integer default 20)`: `security
      definer`, `is_admin()` como primera línea, `UNION ALL` de
      `nuevo_registro` (`profiles` + `auth.users.created_at`, `role =
      'jugador'`) y `nivel_superado` (`intentos_nivel.superado = true`, todos
      los jugadores, `detalle` con `estrellas_obtenidas`/`nivel_id`/
      `tematica_id`), ordenado por `ocurrido_en desc`, acotado a `p_limite`.
- [x] 1.3 `supabase db push` contra el remoto y `supabase db lint --linked`.
- [x] 1.4 Verificación manual: llamar `actividad_reciente()` como admin (ve
      filas) y como jugador (rechazo), usando JWT de prueba vía Auth API
      (mismo enfoque que INT-77/INT-87).

## 2. Panel: capa de datos del dashboard

- [ ] 2.1 `panel/src/lib/dashboard.ts` (o similar): funciones que envuelven
      `supabase.rpc('metricas_home')`, `supabase.rpc('alertas_contenido')`,
      `supabase.rpc('actividad_reciente')`.
- [ ] 2.2 Resolución de nombres legibles: dado un conjunto de `nivel_id`/
      `tematica_id`/`desafio_id` de alertas y actividad, una consulta por
      tabla (`tematicas`, `niveles`, `desafios`) que arme un mapa id→nombre
      legible (ej. `"{tematica.nombre} · Nivel {niveles.orden}"`), sin N+1.
- [ ] 2.3 Tipos TypeScript para las 3 formas de retorno (métricas, alerta,
      evento de actividad) y para el shape ya resuelto que consume la UI.

## 3. Panel: layout compartido

- [ ] 3.1 Componente de layout con sidebar (Home, Jugadores, Ranking,
      Temáticas, Niveles, Preguntas/Desafíos — solo "Home" navega, el resto
      deshabilitado) y header (nombre del admin desde `profiles.nombre` +
      botón "Cerrar sesión" que llama `supabase.auth.signOut()` y redirige a
      `/login`).
- [ ] 3.2 Envolver la ruta `/` (`Home`, ya protegida por `RequireAuth`) con
      el nuevo layout en `App.tsx`.

## 4. Panel: pantalla Home

- [ ] 4.1 Fila de 4 tarjetas de métricas desde `metricas_home()` (jugadores
      totales, activos 7 días, partidas hoy, niveles publicados), sin
      selector de rango.
- [ ] 4.2 Accesos rápidos (nueva temática, nuevo nivel, nuevo desafío)
      renderizados deshabilitados.
- [ ] 4.3 Columna "Actividad reciente" desde `actividad_reciente()` +
      resolución de nombres (2.2), con estado vacío explícito.
- [ ] 4.4 Columna "Alertas de contenido" desde `alertas_contenido()` +
      resolución de nombres (2.2), con estado vacío explícito.

## 5. Tests y calidad

- [ ] 5.1 Tests de la capa de datos (2.1/2.2) con el cliente Supabase
      mockeado: parseo de las 3 RPC y resolución de nombres sin N+1.
- [ ] 5.2 Tests de componente (Vitest + RTL) de Home: métricas, accesos
      rápidos deshabilitados, actividad/alertas con datos y con estado vacío.
- [ ] 5.3 `npm run lint`, `npm run typecheck`, `npm run format:check`,
      `npm run test:coverage` en `panel/`.

## 6. Cierre

- [ ] 6.1 Verificación manual en `panel/` local: login real → Home con datos
      reales del proyecto Supabase remoto (no mock).
- [ ] 6.2 Actualizar `.devplugin/architecture.md` con el estado de INT-81 (y
      la función nueva de `backend/`).
