## 1. Backend — puntuación por parada y ranking global

- [x] 1.1 Crear la migración `backend/supabase/migrations/<ts>_puntuacion_por_camino.sql` con la
      cabecera de comentarios habitual (referencia a `design.md` de esta propuesta y a las
      decisiones D2 y D4).
- [x] 1.2 `create or replace view camino_jugador` añadiendo
      `coalesce(pun.mejor_puntaje, 0) as mejor_puntaje` como **última** columna del `select`,
      sin tocar el orden ni el nombre de ninguna existente (D2). Comentar en el SQL por qué el
      `coalesce` es obligatorio (left join, parada nunca jugada) y por qué no hace falta un
      filtro de `usuario_id` nuevo (reutiliza el alias `pun` ya filtrado por `auth.uid()`).
- [x] 1.3 `create or replace function clasificacion_global` con el CTE `base` sobre
      `progreso_usuario_nivel` + `join camino c on c.id = pun.camino_id`, agregando
      `sum(pun.mejor_puntaje)` y `count(*) filter (where pun.superado)`; eliminar el CTE
      `superados` y su left join (D4). No tocar `ranking`, `top_n`, `resultado` ni `final`.
- [x] 1.4 Verificar que la firma, el tipo de retorno y los `revoke`/`grant` de
      `clasificacion_global` quedan idénticos (`bigint` en `puntuacion`, `integer` en
      `niveles_superados`), y re-emitir los `grant` si el `create or replace` no los conserva.
- [x] 1.5 Pasar el linter de Supabase sobre la migración y
      corregir **en la propia migración**, no en una posterior (Migration Plan, paso 2).
      `supabase db lint` exige `--local` (no hay Docker en esta máquina) o `--linked` (que
      audita el esquema remoto vigente, no una migración sin aplicar).
- [x] 1.6 Aplicar la migración y comprobar a mano que
      `camino_jugador` devuelve `mejor_puntaje` y que `clasificacion_global()` sigue devolviendo
      la fila propia. Requiere `supabase db push` contra el proyecto enlazado.

## 2. Backend — tests SQL

- [x] 2.1 En `backend/supabase/tests/test_clasificacion.sql`, actualizar los asertos de
      `clasificacion_global` que asumen la suma histórica.
- [x] 2.2 Añadir caso: tres intentos sobre la misma parada (300, 800, 500) → `puntuacion` 800,
      no 1600.
- [x] 2.3 Añadir caso: mejorar de 300 a 800 en una parada sube el total en 500, no en 800.
- [x] 2.4 Añadir caso: fila de `progreso_usuario_nivel` con `mejor_puntaje > 0` y `camino_id`
      nulo no cuenta en `clasificacion_global`.
- [x] 2.5 Añadir caso: puntuación de una parada con `activo = false` sigue contando (escenario
      ya existente en la spec, comprobar que no se rompe con el `join camino`).
- [x] 2.6 Añadir caso: con un camino de una sola temática, `clasificacion_global` y
      `clasificacion_por_tematica` devuelven la misma `puntuacion` para el mismo jugador.

## 3. App — gateway

- [x] 3.1 En `app/lib/services/camino_gateway.dart`, añadir `mejorPuntaje` y `puntosAcumulados`
      a `ParadaCamino` (requeridos, no opcionales — D6) y leer `mejor_puntaje` en
      `_mapearParada`.
- [x] 3.2 Escribir la función pura de acumulación (D3): recibe las paradas ordenadas por
      `orden`, devuelve cada una con su acumulado y el total. Documentar que el total es el
      acumulado de la última parada, para que no puedan divergir.
- [x] 3.3 Quitar `puntosFuture` (`from('respuestas_desafio').select('puntos')`) de
      `fetchCamino()` y el `Future.wait` de dos elementos que lo acompaña; `puntosTotales` pasa
      a salir de la acumulación.
- [x] 3.4 Eliminar `sumarPuntos` y actualizar el comentario de
      `nivel_juego_gateway.dart:261` que la referencia (D5).

## 4. App — pantalla del camino

- [x] 4.1 En `app/lib/screens/camino_screen.dart`, `_ParadaTile` deja de recibir
      `puntosTotales` y pinta `parada.puntosAcumulados`; conservar la key
      `parada-puntos-<caminoId>` y el formato con separador de miles.
- [x] 4.2 Actualizar el comentario de `_ParadaTile` que documenta el comportamiento de INT-112
      ("se repite igual en todas las paradas"), que deja de ser cierto.
- [x] 4.3 Ajustar `_buildParadaAnimada` y su llamada (`camino_screen.dart:528`) para no
      propagar `puntosTotales` a la parada.
- [x] 4.4 Comprobar que la píldora de cabecera (`camino-puntos`) y las cuatro pantallas que
      consumen `camino.puntosTotales` (Home, Login, Ranking, Comodines) siguen compilando sin
      cambios propios.

## 5. App — copy del ranking

- [x] 5.1 En `app/lib/screens/ranking_screen.dart`, cambiar el subtítulo de la pestaña Global
      de "acumulado histórico" a "mejor intento por nivel" (D7).
- [x] 5.2 Buscar cualquier otra cadena que prometa acumulación histórica en las pantallas de
      puntuación y corregirla.

## 6. App — tests

- [x] 6.1 Añadir `mejorPuntaje` a los fixtures `_monumentos`, `_monumentos2` y `_banderas` de
      `camino_screen_test.dart`, con valores que hagan legible el acumulado (p. ej. 300, 500, 0).
- [x] 6.2 Reescribir el test `'el indicador izquierdo de cada parada muestra los puntos totales
      del jugador…'` para afirmar el acumulado por parada (300, 800, 800).
- [x] 6.3 Añadir test: el acumulado nunca decrece a lo largo del camino.
- [x] 6.4 Añadir test: el acumulado de la última parada coincide con la píldora `camino-puntos`.
- [x] 6.5 Adaptar `'el indicador izquierdo muestra 0 cuando el jugador no tiene puntos'` al
      fixture nuevo (todas las paradas con `mejorPuntaje = 0`).
- [x] 6.6 En `camino_gateway_test.dart`, sustituir el grupo `sumarPuntos` por tests de la
      función de acumulación: camino vacío, parada sin jugar intercalada, total igual al último
      acumulado.
- [x] 6.7 Añadir test de gateway: `fetchCamino()` no consulta `respuestas_desafio` (escenario
      "El total se calcula sin consultar las respuestas" de la spec).
- [x] 6.8 Revisar los otros usos de `CaminoJugador(...)` en la suite (`login_screen_test`,
      `ranking_screen_test`, `comodines_screen_test`) por si el campo nuevo los rompe.

## 7. Verificación

- [x] 7.1 `flutter analyze` sin avisos (el proyecto está hoy a cero, mantenerlo).
- [x] 7.2 `flutter test` en verde, con la cobertura de las 29 suites intacta.
- [x] 7.3 Tests SQL del backend en verde. El script está
      escrito y envuelto en `BEGIN/ROLLBACK`, pero se ejecuta con
      `supabase db query --linked`, que necesita la migración ya aplicada en el remoto.
- [x] 7.4 `openspec validate int-123-puntuacion-por-camino`.
- [ ] 7.5 Comprobar a mano en la app: jugar una parada, repetirla con peor resultado y confirmar
      que ni la píldora ni el riel suben; repetirla mejorando y confirmar que suben lo justo.
