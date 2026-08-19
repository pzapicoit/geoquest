## 1. Backend: migración SQL

- [x] 1.1 Crear tabla `auditoria_reinicio_progreso` (`id`, `admin_id references profiles(id)`, `jugador_id uuid` sin FK, `alias_jugador text`, `creado_en timestamptz default now()`) con RLS: solo `select` para `is_admin()`, sin políticas de insert/update/delete directas.
- [x] 1.2 Crear RPC `jugadores_listado()` (`security definer`, gate `is_admin()`) que devuelva por jugador con `role = 'jugador'`: `jugador_id`, `alias`, `niveles_superados`, `parada_maxima` (nullable), `puntos_totales`, `tasa_superacion` (nullable), `ultima_partida` (nullable).
- [x] 1.3 Crear RPC `reiniciar_progreso_jugador(p_jugador_id uuid)` (`security definer`, gate `is_admin()`) que: valide que `p_jugador_id` existe con `role = 'jugador'`, inserte la fila de auditoría con el alias actual, borre `progreso_usuario_nivel` e `intentos_nivel` del jugador (cascada a `respuestas_desafio`).
- [x] 1.4 Revocar `execute` de ambas funciones a `public` y concederlo solo a `authenticated` (mismo patrón que `clasificacion_global`/`metricas_home`).
- [x] 1.5 Aplicar la migración local y comprobar manualmente ambas RPCs contra datos de prueba (jugador con partidas, jugador sin partidas, llamada como no-admin, intento de resetear un admin).

## 2. Panel: acceso a datos

- [x] 2.1 Crear `panel/src/lib/jugadores.ts` con `fetchJugadores()` (llama a `jugadores_listado`, mapea snake_case → camelCase) y `reiniciarProgresoJugador(jugadorId)` (llama a `reiniciar_progreso_jugador`).
- [x] 2.2 Tests de `jugadores.ts` (`jugadores.test.ts`) cubriendo el mapeo de filas y la propagación de errores de la RPC.

## 3. Panel: pantalla "Jugadores"

- [x] 3.1 Crear `panel/src/pages/Jugadores.tsx`: cabecera, tarjetas KPI (jugadores totales, puntos medios u otra métrica agregable con los datos ya disponibles), buscador por alias, selector de orden (puntos / parada máxima / alias / tasa de superación), tabla con paginación en cliente y estado vacío de filtros — siguiendo la estructura visual del mock y el patrón de `Preguntas.tsx`.
- [x] 3.2 Añadir el botón de acción "Reiniciar progreso" por fila y el modal de confirmación que exige teclear el alias exacto del jugador para habilitar el botón de confirmar.
- [x] 3.3 Al confirmar, invocar `reiniciarProgresoJugador`, actualizar la fila afectada en el estado local (0 puntos, sin parada superada) y mostrar una confirmación visual (toast o equivalente) del resultado, incluyendo el caso de error.
- [x] 3.4 Registrar la ruta `/jugadores` en `App.tsx` (bajo `RequireAuth` + `PanelLayout`, mismo patrón que el resto de rutas).
- [x] 3.5 Habilitar la entrada "Jugadores" en `NAV_ITEMS` de `PanelLayout.tsx` (`enabled: true`, `to: '/jugadores'`).

## 4. Tests y cobertura

- [x] 4.1 Tests de `Jugadores.tsx` (`Jugadores.test.tsx`): carga inicial, búsqueda, orden, paginación, estado vacío por filtro.
- [x] 4.2 Tests del flujo de reinicio: botón de confirmar deshabilitado hasta que el alias tecleado coincide exactamente, invocación de la RPC al confirmar, actualización de la fila tras un reinicio exitoso, manejo de error de la RPC.
- [x] 4.3 Verificar cobertura del módulo nuevo (`jugadores.ts`, `Jugadores.tsx`) acorde al resto del panel.
