## Context

INT-80 dejó el panel (`panel/`, React 19 + Vite + TS + Tailwind) con login y
una ruta autenticada vacía. INT-87 añadió al backend `metricas_home()` y
`alertas_contenido()` (más 3 RPC de reorden y `desafios_uso`, sin uso en este
ticket) para que el panel pueda agregar datos de **todos** los jugadores pese
a que la RLS de INT-77 es "cada cual lo suyo". Este ticket construye la
pantalla Home consumiendo ese backend, y descubre que uno de los 6 requisitos
del ticket (Linear INT-81) — la columna "Actividad reciente" — no tiene
ninguna función/vista que lo respalde: ni `metricas_home`/`alertas_contenido`
lo cubren, ni un admin puede leer `intentos_nivel`/`profiles` directo por REST
(RLS "propio usuario" de INT-77). Se añade una función nueva,
`actividad_reciente()`, mismo patrón que INT-87.

El diseño visual llega de Claude Design (`[Admin] - Home.dc.html`), leído vía
el MCP de diseño. Es una maqueta con datos de ejemplo fijos (`Component` con
un `state.range` y arrays de mock) — sirve para el layout/estilos, no como
contrato de datos: donde la maqueta y el backend real difieren (selector de
rango, badges de la nav, import CSV), manda el backend real y el checklist de
Linear, no la maqueta.

## Goals / Non-Goals

**Goals:**
- Layout fijo del panel (sidebar + header) reutilizable por las pantallas
  futuras de la nav, aunque solo Home tenga contenido en este ticket.
- Las 4 tarjetas de métricas, accesos rápidos, columna de alertas y columna
  de actividad reciente descritas en el checklist de INT-81, con datos reales
  (no mock) desde Supabase.
- `actividad_reciente()`: nueva función de solo lectura, gateada a admin,
  mismo patrón `security definer` + `is_admin()` de INT-87.

**Non-Goals:**
- Selector interactivo 24 h / 7 d / 30 d de la maqueta: `metricas_home()`
  solo expone una ventana fija (activos = últimos 7 días). No se simula el
  resto en cliente.
- Badges de conteo en la nav lateral (Jugadores 4 907, Temáticas 12, Niveles
  86, Desafíos "3 ⚠" en la maqueta) y el enlace "Importar desafíos por CSV":
  no están en el checklist de Linear y no aportan nada sin las pantallas que
  representan. Nav renderiza solo etiqueta + enlace.
- Pantallas de destino de la nav (Jugadores, Ranking, Temáticas, Niveles,
  Preguntas/Desafíos) y de los accesos rápidos (nueva temática/nivel/
  desafío): no existen todavía (tickets futuros). Sus enlaces quedan
  deshabilitados en vez de apuntar a rutas 404.
- "PTS" (hito de puntos / ranking) de la maqueta: no hay tabla de puntuación
  acumulada ni ranking todavía; el checklist de INT-81 solo pide altas de
  jugador y niveles superados con sus estrellas, ambos cubiertos por
  `actividad_reciente()`.

## Decisions

### D1: `actividad_reciente()` — mismo patrón que `metricas_home`/`alertas_contenido`

`security definer` + `if not is_admin() then raise exception`, devolviendo
una tabla genérica `(tipo text, ocurrido_en timestamptz, texto text, detalle
jsonb)` (mismo criterio de D5 de INT-87: forma heterogénea sin forzar
columnas que no aplican a ambos tipos), con dos ramas por `UNION ALL`:

- `nuevo_registro`: altas de `profiles` con `role = 'jugador'`. El
  timestamp de alta no vive en `profiles` (sin columna `created_at`) sino en
  `auth.users.created_at` — la función, al ser `security definer` propiedad
  de `postgres`, puede leer `auth.users` igual que `handle_new_user` (INT-75)
  ya lo hace en la dirección contraria (trigger de alta). `detalle` lleva
  `{}` (sin datos adicionales hoy).
- `nivel_superado`: `intentos_nivel` con `superado = true`, de **todos** los
  jugadores (no solo el admin que invoca), con `detalle` llevando
  `estrellas_obtenidas`, `nivel_id` y `tematica_id` para que el cliente
  resuelva el nombre legible (ver D3).

Ordenada por `ocurrido_en desc`, con un límite (`p_limite integer default
20`) para no devolver el historial completo — a diferencia de
`metricas_home`/`alertas_contenido` (agregados/alertas acotadas por
naturaleza), un feed de actividad crece sin límite con el tiempo.

Alternativa descartada: dos funciones separadas (`altas_recientes`,
`niveles_superados_recientes`). Se descarta por la misma razón que D5 de
INT-87 — el panel pinta una sola columna "Actividad reciente" y prefiere una
llamada a dos.

### D2: Sin selector de rango — `metricas_home()` no lo soporta

La maqueta simula 3 juegos de datos distintos por rango en el cliente
(`state.range`), pero `metricas_home()` real solo calcula una ventana fija
(`jugadores_activos_7d`). Extender la RPC con un parámetro de rango es
plausible pero no lo pide el checklist de Linear (no menciona el selector) y
convertiría una tarjeta fija ("activos últimos 7 días", tal cual la pide el
ticket) en una API parametrizada sin caso de uso confirmado todavía. Se deja
como mejora futura si el producto lo pide explícitamente.

### D3: Nombres legibles en Alertas/Actividad se resuelven en el cliente

`alertas_contenido()` devuelve `referencia_id` (uuid) sin nombre legible;
`actividad_reciente()` (D1) devuelve `nivel_id`/`tematica_id` en `detalle`
por la misma razón. En vez de hacer join dentro de cada función SQL, el
panel resuelve nombres con lecturas REST aparte (`tematicas`, `niveles`,
`desafios` — las tres de lectura permitida para un admin autenticado por la
RLS de INT-77), agrupando los ids necesarios de la respuesta de alertas/
actividad en una sola query por tabla (evita N+1).

Alternativa descartada: que `alertas_contenido`/`actividad_reciente` incluyan
ya el texto resuelto (ej. concatenar `tematicas.nombre` + `niveles.orden` en
SQL). Se descarta porque acopla el formato de presentación (cómo se muestra
"Fiordos de Noruega · Nivel 9") a una función de backend pensada para
agregados neutrales; further, `alertas_contenido()` ya está mergeada
(INT-87) y no se toca aquí sin necesidad.

### D4: Layout compartido (sidebar + header) sin pantallas propias

Se extrae un componente de layout (nav lateral fija + header) que envuelve
`Home` y quedará listo para las pantallas futuras de la nav. Los enlaces de
la nav a Jugadores/Ranking/Temáticas/Niveles/Preguntas-Desafíos, y los 3
accesos rápidos, se renderizan deshabilitados (visualmente presentes, sin
`onClick`/navegación) en vez de apuntar a rutas que resolverían en la página
"no encontrada" — mejor UX que un enlace roto, y no requiere crear rutas
placeholder vacías.

## Risks / Trade-offs

- **[Riesgo]** `security definer` en `actividad_reciente()` leyendo
  `auth.users` amplía la superficie de una función ya sensible → **Mitigación**:
  mismo patrón ya auditado (`is_admin()` como primera línea, antes de tocar
  cualquier tabla; ver D3 de INT-87), y la única columna leída de
  `auth.users` es `created_at`.
- **[Trade-off]** Sin selector de rango (D2) y sin badges de nav, la pantalla
  entregada es visualmente más simple que la maqueta → aceptado: preferible
  a simular datos con `state` de cliente que no corresponden a ninguna
  consulta real.
- **[Riesgo]** Deshabilitar accesos rápidos/nav (D4) puede leerse como
  "roto" si no se distingue de un botón normal → **Mitigación**: estilo
  visual distinto (opacidad reducida) para lo deshabilitado, no solo quitar
  el `href`.

## Migration Plan

Una migración SQL nueva (`supabase/migrations/<timestamp>_actividad_reciente.sql`)
con la función `actividad_reciente()`. Aditiva, sin tocar funciones/vistas de
INT-87. Sin rollback especial (mismo criterio que INT-87: revertir con un
`DROP FUNCTION` posterior si hiciera falta).

En `panel/`, cambios solo de aplicación (componentes, cliente Supabase,
rutas) — sin migración de datos ni de infraestructura.
