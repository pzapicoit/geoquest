## 1. Vista (backend)

- [x] 1.1 Nueva migración `backend/supabase/migrations/`: crear vista `camino_jugador` (join `camino` → `niveles` → `tematicas`, left join `progreso_usuario_nivel` filtrado por `usuario_id = auth.uid()`, CTE de estrellas acumuladas, columnas `desbloqueado` y `es_actual` calculadas — ver SQL de design.md decisión 1)
- [x] 1.2 Comentario de la migración: documentar por qué la vista no usa `security_invoker` y en su lugar filtra explícitamente por `auth.uid()` (mismo patrón que `desafios_uso`, D4 de `INT-87`), para que el próximo cambio a esta vista no lo pase por alto

## 2. Verificación manual (sin runner de tests SQL, ver `.devplugin/architecture.md`)

- [x] 2.1 Contra el remoto, con dos usuarios de prueba (anónimos) y un progreso distinto en cada uno: confirmar que cada uno recibe en `camino_jugador` únicamente su propio `superado`/`estrellas_obtenidas`/`desbloqueado`/`estrellas_acumuladas_usuario`. Hecho: usuario A con 2 posiciones superadas y usuario B sin ninguna, cada uno vio exclusivamente su propio progreso.
- [x] 2.2 Con un usuario de prueba sin ningún intento cerrado: confirmar que todas las posiciones aparecen con `superado = false`, `estrellas_obtenidas = 0`, y que la de `estrellas_requeridas = 0` aparece `desbloqueado = true`. Confirmado con el usuario B sobre 4 posiciones (1 real + 3 sintéticas).
- [x] 2.3 Con un usuario de prueba con progreso parcial: confirmar que `es_actual = true` cae exactamente en la primera posición no superada por `orden`, y en ninguna otra. Confirmado con el usuario A (2 posiciones superadas de 4, `es_actual` en la 3ª).
- [x] 2.4 Con un usuario que supera todo el camino de prueba: confirmar que ninguna posición queda `es_actual = true`. Encontrado y corregido un bug real en el camino: sin `coalesce`, `es_actual` daba `NULL` (no `false`) en ese caso porque `min(...) over ()` no matchea nada cuando no queda ninguna posición sin superar — la migración ya incluye el `coalesce(..., false)` y quedó reverificado tras el fix.
- [x] 2.5 Eliminar los datos de prueba (usuarios anónimos, `progreso_usuario_nivel`, `intentos_nivel`) creados para 2.1-2.4. Hecho: borrado en cascada de la temática/niveles/camino sintéticos y de los 2 usuarios anónimos vía Admin API; verificado que `camino`/`tematicas` volvieron a su estado original (1 posición, 2 temáticas reales).

## 3. Documentación y validación

- [x] 3.1 `openspec validate int-96-vista-camino-jugador --strict`
- [x] 3.2 Actualizar `.devplugin/architecture.md` con la vista `camino_jugador` (columnas y regla de desbloqueo/posición actual)
