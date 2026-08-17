## Context

`camino_jugador` (INT-96/INT-98) ya expone, en una sola consulta y por
posición (`orden` ascendente): `nivel_id`, `nivel_nombre` (nullable),
`tematica_id`, `tematica_nombre`, `superado`, `estrellas_obtenidas`,
`estrellas_acumuladas_usuario`, `desbloqueado` (ya recalculado sobre
estrellas acumuladas) y `es_actual`. No expone imagen ni puntos totales.

El diseño visual de referencia (`[App] - Camino vertical.dc.html` en el
proyecto Claude Design "GeoQuest") es una demo de un framework de
prototipado (`x-dc`/`DCLogic`), no código portable: fija el contrato
visual y de interacción, no la implementación. Su `LEVELS` de ejemplo
intercala temáticas libremente y no modela la parada "frontera" — esa
pieza solo existe, con otro lenguaje visual, en un mock hermano ya
superado (`v6`). La pantalla se implementa nativa en Flutter siguiendo
las convenciones ya usadas en `app/lib/services/*_gateway.dart`
(gateway abstracto + implementación Supabase, testeable con un fake).

## Goals / Non-Goals

**Goals:**
- Reemplazar `TopicsMapPlaceholderScreen` por la Home real: camino
  vertical con barra superior, estados superado/actual/bloqueado,
  parada frontera, auto-scroll a la posición actual y navegación al
  tocar una parada desbloqueada.
- Resolver arte por parada y puntos totales sin tocar el backend.

**Non-Goals:**
- No implementa la pantalla de juego en sí (INT-91): tocar una parada
  desbloqueada navega a un stub de "Nivel N" hasta que exista.
- No implementa la pantalla de perfil: el botón de perfil es un stub
  (SnackBar), igual que el propio mock de referencia lo deja como
  "pendiente de diseñar".
- No replica animaciones de scroll del mock (parallax, escala/opacidad
  por proximidad al centro): se simplifican a transiciones de estado
  discretas (bloqueado/actual/superado) más un scroll suave al abrir.
- No crea ninguna vista o función nueva en el backend.

## Decisions

**D1 — Arte por parada: `tematicas.imagen_portada`, resuelto en una
segunda consulta.**
`niveles` no tiene columna de imagen; `tematicas.imagen_portada` sí, es
obligatoria y su propia spec la define como pensada para "mostrarse como
título del mundo en el mapa del jugador". `camino_jugador` no la expone.
En vez de ampliar esa vista (reabriría un artefacto ya archivado de
INT-96 por una necesidad puramente de app), el gateway hace una segunda
consulta `tematicas.select('id, imagen_portada').in('id', tematicaIds)`
sobre los `tematica_id` distintos del camino, y usa `imagen_portada` tal
cual: esa columna ya guarda la URL pública completa (el panel la resuelve
una vez con `getPublicUrl` al subir la portada y persiste la URL
resultante, no la ruta dentro del bucket — confirmado consultando la fila
real; INT-90 asumió al proponer que guardaba solo la ruta y volvía a
llamar a `getPublicUrl` sobre ella, lo que rompía la URL y hacía caer al
color de acento en vez de la imagen real, corregido en el ciclo de
`/fix`). Granularidad por temática, no por nivel:
igual que hace el propio mock de referencia (reutiliza el mismo arte
para varios niveles de una temática).
Alternativa descartada: añadir `imagen_portada` a `camino_jugador`
directamente — más simple en runtime, pero mezcla una necesidad de
presentación de app dentro de una vista de dominio ya archivada y
verificada.

**D2 — Puntos totales: suma client-side sobre `respuestas_desafio`.**
No existe agregación de puntos en el backend. La RLS de `respuestas_desafio`
(spec `game-data-model`) ya restringe el `select` a las filas del propio
usuario vía `intento_id -> intentos_nivel.usuario_id`, así que el gateway
solo necesita `respuestas_desafio.select('puntos')` — sin joins ni
filtros adicionales — y suma `puntos` en Dart. Aceptado como límite
conocido (ver Riesgos):
crece con el nº histórico de respuestas del jugador, no con el nº de
niveles. Alternativa descartada: una vista/función backend de
agregación — expande el alcance de un issue etiquetado "App" sin que
ningún bloqueante lo pida; se deja como mejora futura si el volumen lo
justifica.

**D3 — Frontera: parada sintética construida en el cliente, no una fila
de `camino`.**
Se recorre `camino_jugador` en orden y se inserta una parada "frontera"
sintética cada vez que `tematica_id` cambia entre dos posiciones
consecutivas (fin de un tramo de una temática, inicio del siguiente).
Su estado de bloqueo usa los mismos campos ya calculados en la
*siguiente* posición real: bloqueada si esa posición trae
`desbloqueado = false`, y el mensaje de estrellas que faltan se calcula
como `max(1, siguiente.estrellas_requeridas - estrellas_acumuladas_usuario)`.
No necesita `camino_id` propio ni toque de backend.
Riesgo aceptado: como el propio dominio permite intercalar temáticas en
cualquier orden (spec `game-data-model`, "Camino como secuencia global
ordenada de niveles"), un camino muy intercalado generaría una frontera
en cada cambio de tema. Se acepta como comportamiento correcto dado el
contrato actual — ver Riesgos.

**D4 — Orden de renderizado y auto-scroll.**
El camino crece de abajo (nivel de `orden` 1) hacia arriba, como en el
mock. Se construye la lista en `orden` ascendente y se renderiza en un
`ListView` con `reverse: true`, con alturas de fila fijas conocidas de
antemano (parada normal vs. frontera tienen alturas distintas pero
fijas), de forma que la posición de scroll de cualquier parada se
calcula sin esperar a un layout pass. Al montar la pantalla, se hace
`jumpTo`/`animateTo` a la posición de la parada `es_actual` (o, si el
camino está completo y ninguna fila es actual, al final ya superado).

**D5 — Gateway.**
`CaminoGateway` (abstracto) con un único método
`Future<CaminoJugador> fetchCamino()` que devuelve las paradas ya
combinadas con su URL de arte y el total de puntos, ejecutando las tres
consultas (`camino_jugador`, `tematicas`, `respuestas_desafio`) en
paralelo con `Future.wait`. `SupabaseCaminoGateway` es la única
implementación real; un fake in-memory permite testear la pantalla sin
red, siguiendo el patrón de `ProfileGateway`.

**D6 — Ambientación por temática.**
El mock de referencia no varía el fondo completo de la pantalla por
temática (solo el arte de cada tarjeta). Para cumplir el criterio de
aceptación "ambientación que varía sutilmente por temática" sin inventar
un asset nuevo, se deriva un color de acento por temática (paleta fija
rotando por `tematica_id`) aplicado al riel/ticks de las paradas de esa
temática, mientras el fondo general de la pantalla se mantiene como en
el mock. Alternativa descartada: pedir un asset de fondo por temática —
no existe ese campo en el modelo de datos y excede el alcance de este
issue de app.

## Risks / Trade-offs

- **[Riesgo] Suma de puntos client-side no escala indefinidamente** con
  el histórico de respuestas del jugador → Mitigación: aceptado para el
  volumen actual; si se vuelve lento, migrar a una vista/función
  backend de agregación (fuera de alcance aquí).
- **[Riesgo] Frontera basada en cambio de `tematica_id` puede
  multiplicarse si el camino intercala temáticas** en vez de agruparlas
  en bloques → Mitigación: es el comportamiento correcto dado el
  contrato de dominio actual; observación de producto para quien cura
  el contenido del camino en el panel: agrupar cada temática en un
  bloque contiguo evita fronteras redundantes (se anota como
  observación UX, no se fuerza en el esquema).
- **[Riesgo] Arte por temática, no por nivel** — dos niveles de la misma
  temática se ven iguales → Mitigación: aceptado, coincide con el propio
  mock de referencia y con lo único que el modelo de datos ofrece hoy
  (`tematicas.imagen_portada`); si en el futuro se añade arte por nivel,
  el gateway solo necesita un nuevo campo, no cambia de forma.
- **[Riesgo] Navegación a la pantalla de juego es un stub** hasta INT-91
  → Mitigación: se documenta explícitamente como no-goal; el stub deja
  claro qué nivel se iba a abrir para facilitar la prueba manual.

## Migration Plan

No aplica migración de datos. Cambio puramente de app:
1. Añadir `CaminoGateway`/`SupabaseCaminoGateway` y sus modelos.
2. Añadir `CaminoScreen` y widgets de parada/frontera.
3. Cambiar el destino post-splash de `TopicsMapPlaceholderScreen` a
   `CaminoScreen`.
4. Eliminar `TopicsMapPlaceholderScreen` una vez sustituida.
Sin rollback especial: revertir el commit restaura el placeholder.

## Open Questions

- Ninguna bloqueante para implementar. Queda abierta la decisión de
  producto (no técnica) de si el panel debería, en el futuro, forzar
  agrupación contigua por temática en el camino — ver Riesgos.
