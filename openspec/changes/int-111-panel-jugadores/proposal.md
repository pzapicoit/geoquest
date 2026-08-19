## Why

El panel de administración no tiene ninguna pantalla para ver a los jugadores ni para intervenir sobre su progreso. Cuando un jugador reporta un bug de puntuación, hace trampa, o simplemente pide "empezar de cero", el equipo no tiene forma de resolverlo sin tocar la base de datos a mano. INT-111 introduce la pantalla "Jugadores" del panel (listado + búsqueda) y la primera acción administrativa real sobre esos datos: reiniciar el progreso de un jugador.

## What Changes

- Nueva pantalla `/jugadores` en el panel (React): listado de jugadores con búsqueda por alias, orden (puntos, nivel, alias, acierto) y paginación en cliente. Reproduce la estructura visual del mock de Claude Design (`[Admin] - Jugadores.dc.html`: cabecera, tarjetas KPI, tabla, paginación) adaptada a los datos reales.
- Activa el enlace "Jugadores" en `PanelLayout` (hoy deshabilitado) apuntando a la nueva ruta.
- Nueva RPC `jugadores_listado()` (security definer, gate `is_admin()`) que agrega por jugador: alias, nivel más alto superado, puntos totales, % de acierto y fecha de última partida.
- Nueva RPC `reiniciar_progreso_jugador(p_jugador_id uuid)` (security definer, gate `is_admin()`) que en una transacción: borra `progreso_usuario_nivel` e `intentos_nivel` (cascada a `respuestas_desafio`) del jugador indicado, y registra la acción en una tabla de auditoría nueva (`auditoria_reinicio_progreso`: admin, jugador, alias del jugador en el momento del reinicio, fecha). La cuenta, el alias y el acceso del jugador no se tocan.
- Modal de confirmación en el panel: exige escribir el alias exacto del jugador antes de habilitar el botón de reinicio (más estricto que una simple casilla, dado que la acción es irreversible y borra datos).
- **Fuera de alcance de este ticket** (el mock las muestra, pero no hay soporte de datos ni lo pide el ticket): email de contacto, estado de cuenta (activo/inactivo/suspendido), acción "Suspender cuenta", selección múltiple/acciones en lote y exportar a CSV. Los jugadores de GeoQuest son anónimos (sin email) y no existe hoy ningún concepto de suspensión de cuenta en el esquema. Quedan para un ticket futuro si se decide construir esa base.

## Capabilities

### New Capabilities
- `panel-players-listing`: listado de jugadores en el panel (búsqueda, orden, paginación) respaldado por la RPC `jugadores_listado`.
- `panel-player-progress-reset`: acción administrativa de reinicio del progreso de un jugador, con confirmación explícita y registro de auditoría.

### Modified Capabilities
(ninguna — no cambia el comportamiento de specs existentes)

## Impact

- **Backend**: nueva migración con 2 RPCs (`jugadores_listado`, `reiniciar_progreso_jugador`) y 1 tabla nueva (`auditoria_reinicio_progreso`) con su RLS (solo admin lee).
- **Panel**: nueva página `Jugadores.tsx`, nuevo módulo `lib/jugadores.ts` (fetch + reinicio), ruta en `App.tsx`, entrada de nav habilitada en `PanelLayout.tsx`.
- No afecta a la app móvil (Flutter) ni a specs de jugador existentes.
