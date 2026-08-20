## Context

`intentos_nivel` (tabla, nombre histórico; se identifica por `camino_id` desde INT-106) agrupa los desafíos de una partida vía `intento_desafios` (snapshot fijado por `iniciar_intento_parada`). El cronómetro que ve el jugador (`CuentaAtrasDeDesafio`, `app/lib/screens/cuenta_atras_de_desafio.dart`) es puramente de presentación: cuelga de un instante `_fin` fijado una vez por `arrancar()`, y solo dispara `alAgotarse()` (auto-envío) — el bonus de puntuación real lo calcula el servidor en `calcular_puntaje` a partir de `intento_desafios.mostrado_en` (tiempo real transcurrido, INT-99). `desafios` no tiene ningún campo de país; solo `nombre_lugar` (el lugar real, se revela al terminar) y `lat_real`/`lng_real`. El mapa (`app/lib/mapa/`) dibuja el mundo con un `CustomPainter` propio sobre una proyección Mercator manual, sin ningún SDK de mapas.

## Goals / Non-Goals

**Goals:**
- Inventario de 4 tipos de comodín por jugador, con semilla 1/1/1/0, consumible una vez por intento.
- Efecto real (no solo un toast) para cada tipo, sin abrir una vía para deducir la respuesta completa por otro camino que no sea jugar.
- Obtención por anuncio (AdMob Rewarded, INT-117) con tope diario, diseñada para degradar con gracia si INT-117 aún no está implementada.

**Non-Goals:**
- Canje por puntos, pack de pago, cualquier IAP.
- Verificación server-side (SSV) del visionado del anuncio en esta primera versión — se acepta el reward que reporta el cliente.
- Gestión de inventario de comodines desde el panel admin.
- Backfill completo de `pais` para los 83 desafíos existentes (se deja como tarea de contenido, no bloquea el despliegue del código).

## Decisions

**D1 — Inventario como filas `(usuario_id, tipo)` en vez de columnas fijas.** Nueva tabla `comodines_inventario(usuario_id uuid, tipo tipo_comodin, cantidad integer)` con PK compuesta, en vez de 4 columnas en `profiles`. Alternativa descartada: columnas fijas (`profiles.comodines_tiempo`, etc.) — funciona igual para 4 tipos conocidos, pero un tipo nuevo exigiría una migración de esquema; con filas basta un `insert` de catálogo. Sembrado en el mismo trigger `handle_new_user` que ya crea el perfil (INT-75), insertando las 4 filas iniciales (1/1/1/0).

**D2 — Marca de uso en el propio intento, no un log aparte.** `intentos_nivel` gana `comodin_usado tipo_comodin` (nullable). Un valor no nulo bloquea cualquier otro uso en ese intento. Se elige esto en vez de una tabla `comodines_usos` porque la regla es "como mucho 1 por intento": una columna nullable expresa la invariante directamente y permite un `update ... where comodin_usado is null` atómico (ver D5, concurrencia).

**D3 — El comodín `tiempo` es enteramente client-side.** Como el cronómetro visible no alimenta el cálculo de puntaje (D6/D7 de INT-99: el bonus usa `mostrado_en` real, no lo que enseña la barra), extender 15s el margen antes del auto-envío no requiere tocar el servidor más allá de consumir el comodín. Se añade `CuentaAtrasDeDesafio.extender(Duration)`: adelanta `_fin`, y suma esa duración a `_total`/`_restante` para que la barra y el umbral crítico seleccionan escala coherente. `usar_comodin` para tipo `tiempo` solo decrementa inventario y marca el intento; el payload de vuelta lleva `extra_segundos` para que la app sepa cuánto extender.

**D4 — `pais` como columna nueva en `desafios`, no derivado en tiempo de lectura.** No hay dataset de fronteras por país disponible hoy (el asset del mapa es solo costa/relleno, sin atribución por país — ver architecture.md, "no lleva ningún topónimo"), así que derivarlo geométricamente no es viable sin traer un dataset nuevo. Se añade `desafios.pais text` (nullable), con un campo homólogo en el formulario de preguntas del panel (mismo tratamiento que `pista` en INT-116: opcional, no bloquea guardar). Si `pais` es `NULL` para el desafío actual, `usar_comodin` devuelve un error controlado (`pais_no_disponible`) **sin** decrementar inventario ni marcar el intento — el jugador no pierde su comodín por una laguna de contenido.

**D5 — `usar_comodin` valida disponibilidad de dato antes de decrementar, y decrementa de forma atómica.** Orden dentro de la función: (a) comprobar que el intento es del usuario y sigue abierto: (b) para `pais`, comprobar que el desafío actual tiene `pais` no nulo — si no, abortar con error, no tocar nada; (c) `update comodines_inventario set cantidad = cantidad - 1 where usuario_id = auth.uid() and tipo = p_tipo and cantidad > 0 returning cantidad` — si no actualiza ninguna fila (cantidad ya en 0), abortar; (d) `update intentos_nivel set comodin_usado = p_tipo where id = p_intento_id and comodin_usado is null returning id` — si no actualiza ninguna fila (alguien ya usó otro comodín en este intento, posible carrera), abortar y revertir (c) dentro de la misma transacción. Al ser una única función `plpgsql` con estas comprobaciones secuenciales, Postgres las ejecuta en una sola transacción: cualquier `raise exception` revierte los `update` previos.

**D6 — Concesión por anuncio sin SSV en v1.** `conceder_comodin_por_anuncio()` confía en que la app solo la llama tras el callback `onUserEarnedReward` del SDK de AdMob. Tope diario contado sobre una tabla ligera `comodines_concesiones_anuncio(usuario_id, fecha, cantidad)` (una fila por usuario y día, incrementada con `on conflict do update`), no sobre timestamps individuales — más simple de consultar y de resetear. El tipo concedido es aleatorio uniforme entre los 4 (`floor(random()*4)`).

**D7 — Overlay de radio en el mapa reutiliza la proyección existente.** `km1000`/`km500` devuelven `lat_real`/`lng_real` del desafío actual (ya usados internamente por `responder_desafio`, nunca antes expuestos al cliente para el desafío en curso). La app proyecta ese punto con la misma Mercator de `MapaMundiController` y dibuja un círculo del radio pedido — no un dataset nuevo, solo un dato adicional que hoy no viajaba al cliente hasta la respuesta.

## Risks / Trade-offs

- **[Riesgo] Sin SSV, un cliente modificado podría llamar `conceder_comodin_por_anuncio()` sin ver el anuncio.** → Mitigación: tope diario bajo (propuesta: 5) limita el daño; el contrato de la función no cambia si se añade SSV después (Edge Function que verifique con AdMob y sea la única llamadora), así que no es una pared sino una `v1` deliberadamente simple.
- **[Riesgo] Condición de carrera entre dos usos casi simultáneos del mismo intento (dos pestañas/dispositivos).** → Mitigación: D5 hace atómico el `update ... where comodin_usado is null`; el segundo en llegar falla limpio.
- **[Riesgo] `pais` nulo en las preguntas ya existentes deja el comodín "pais" inservible al principio.** → Mitigación real (ajustada durante la implementación): ni `iniciar_intento_parada` ni `desafios_para_jugar` exponen `pais` antes de consumir el comodín, así que el cliente no puede deshabilitarlo de antemano como se planteó aquí originalmente — en su lugar, `usar_comodin` comprueba la disponibilidad antes de decrementar y rechaza sin coste (`pais_no_disponible`) si no hay dato, y la app lo muestra como un aviso normal al tocar. Se backfilla con el tiempo, no bloquea el release.
- **[Trade-off] El comodín de tiempo no afecta a la puntuación.** Se acepta conscientemente (D3): es coherente con que el reloj visible siempre fue cosmético, y evita reabrir el diseño de `calcular_puntaje`. Se compensa con copy explícito en la UI.

## Migration Plan

1. Migración de esquema: `create type tipo_comodin as enum ('tiempo','pais','km1000','km500')`; `create table comodines_inventario`; `alter table intentos_nivel add column comodin_usado tipo_comodin`; `alter table desafios add column pais text`.
2. Actualizar `handle_new_user` (trigger de INT-75) para sembrar las 4 filas de inventario del perfil nuevo.
3. RPCs: `usar_comodin`, `conceder_comodin_por_anuncio`, `mis_comodines()` (vista/función de lectura para la app).
4. Panel: campo `pais` en el formulario de preguntas (`panel-questions-form`).
5. App: `CuentaAtrasDeDesafio.extender`, tray de comodines en pantalla de juego, pill en Home, pantalla Comodines, overlay de radio en el mapa.
6. Sin cambios destructivos: todo es aditivo (columnas nullable, tabla nueva, enum nuevo). Rollback = drop de las piezas nuevas, sin tocar filas existentes de `intentos_nivel`/`desafios` más allá de las columnas añadidas.

## Open Questions

- Tope diario de comodines por anuncio: ¿5/día (propuesta del diseño visual) o otro número?
- Backfill de `pais` para los 83 desafíos existentes: ¿a mano por un admin, o apoyado en el pipeline de IA de INT-113 (sugerir país a partir de `nombre_lugar`/coords, admin revisa)?
- ¿Cuándo se aborda la verificación SSV de AdMob? Queda fuera de esta historia, pero conviene decidir en qué momento del roadmap se retoma.
