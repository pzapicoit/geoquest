## Why

El panel de administración solo tiene login (INT-80): tras autenticarse, el
admin cae en una pantalla vacía ("El contenido del panel llega en INT-81").
INT-81 construye la pantalla Home — la vista de estado del juego al entrar —
para que el admin tenga un punto de partida útil en vez de una página en
blanco.

## What Changes

- Layout fijo del panel: navegación lateral (Home, Jugadores, Ranking,
  Temáticas, Niveles, Preguntas/Desafíos) y header con nombre del admin
  logueado + cerrar sesión. Solo Home tiene contenido; el resto de enlaces
  quedan como navegación fija sin pantalla propia todavía (fuera de alcance
  de este ticket).
- Pantalla Home: fila de 4 tarjetas de métricas (jugadores totales, activos
  7 días, partidas hoy, niveles publicados) sobre `metricas_home()`
  (INT-87).
- Accesos rápidos: nueva temática, nuevo nivel, nuevo desafío. Como ninguna
  de esas pantallas existe aún, los tres enlazan a rutas placeholder (fuera
  de alcance crear los formularios).
- Columna "Alertas de contenido" sobre `alertas_contenido()` (INT-87),
  resolviendo en cliente el nombre legible de cada nivel/desafío referenciado
  (join contra `niveles`/`tematicas`/`desafios`, de lectura permitida para un
  admin autenticado).
- Columna "Actividad reciente": **no tiene backend hoy**. Ni
  `metricas_home`/`alertas_contenido` ni ninguna vista existente exponen un
  feed de altas de jugadores o niveles superados, y la RLS de `intentos_nivel`
  (propio usuario únicamente, INT-77) impide que un admin lo consulte
  directo por REST. Se añade una función nueva, `actividad_reciente()`,
  mismo patrón `security definer` + `is_admin()` que `metricas_home`, que
  agrega altas de jugador (vía `auth.users.created_at`, no hay columna
  equivalente en `profiles`) y niveles superados (`intentos_nivel.superado`,
  con sus `estrellas_obtenidas`) de todos los jugadores.
- **Fuera de alcance**: el selector 24 h / 7 d / 30 d que aparece en el
  diseño no tiene soporte real — `metricas_home()` devuelve una sola
  ventana fija (activos = últimos 7 días). Se implementa la fila de
  métricas con esa única ventana, sin selector interactivo, en vez de
  simular datos que la base no puede respaldar.

## Capabilities

### New Capabilities
- `panel-home-dashboard`: pantalla Home del panel — layout con navegación
  lateral fija y header, tarjetas de métricas, accesos rápidos, columnas de
  actividad reciente y alertas de contenido.
- `panel-recent-activity`: función `actividad_reciente()` que agrega altas
  de jugadores y niveles superados (todos los jugadores) para consumo del
  panel, gateada a `profiles.role = 'admin'`.

### Modified Capabilities
(ninguna — `panel-home-metrics`, `content-alerts` y `panel-login-ui` se
consumen tal cual, sin cambiar sus requisitos)

## Impact

- `backend/`: nueva migración con `actividad_reciente()` (SQL, mismo patrón
  que `metricas_home`/`alertas_contenido` de INT-87).
- `panel/`: nuevas piezas en `src/` — layout compartido (sidebar + header),
  página Home con las 4 secciones, y el código de acceso a Supabase para
  `metricas_home`, `alertas_contenido` y `actividad_reciente` (RPC) más las
  lecturas REST auxiliares (`tematicas`, `niveles`, `desafios`) para resolver
  nombres legibles en alertas y actividad.
- Sin cambios en `app/` (Flutter) ni en RLS existente.
