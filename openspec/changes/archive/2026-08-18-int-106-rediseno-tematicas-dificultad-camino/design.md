## Context

Hoy `niveles` (FK a `tematicas`) es la entidad curada a mano: define `puntaje_minimo_superar`, `umbral_estrella_1/2/3`, `preguntas_por_partida` y `segundos_por_desafio` (INT-99), y `nivel_desafios` fija qué preguntas del banco (`desafios`) le pertenecen y en qué orden. `camino` es una secuencia global (`orden`, `estrellas_requeridas`) que apunta a `nivel_id`. `intentos_nivel`, `intento_desafios`, `respuestas_desafio` y `progreso_usuario_nivel` cuelgan de `nivel_id`. La selección de preguntas al arrancar un intento (`iniciar_intento_nivel`, INT-95) sortea sobre `nivel_desafios`. El cierre de intento y el desbloqueo del camino (`level-progression`, INT-79/INT-98) leen `puntaje_minimo_superar`/`umbral_estrella_*` de `niveles` y recorren `camino` por `nivel_id`. La curva de puntuación por distancia (`calcular_puntaje_por_distancia`, INT-101, suelo 50/máx 5000/k 1500) y el bonus por rapidez (`calcular_puntaje`, INT-99) no cambian en este trabajo.

Este cambio sustituye la curación manual por una dificultad fija por pregunta y valores por defecto por dificultad, de forma que una parada del camino ya no referencia un nivel curado sino una pareja temática+dificultad resuelta por sorteo.

## Goals / Non-Goals

**Goals:**
- `desafios` lleva una `dificultad` de un catálogo cerrado de 5 valores.
- Cada dificultad tiene valores por defecto editables (preguntas por partida, segundos por desafío, puntuación mínima, umbrales de estrella derivados).
- Una parada del camino resuelve directamente temática+dificultad (con overrides opcionales de esos valores), sin entidad "nivel" intermedia que curar.
- Migración automática de `niveles`/`nivel_desafios`/`camino` existentes, sin pérdida de datos ni regresión de comportamiento el día del despliegue.
- Compatibilidad con INT-99/INT-101: no se toca `calcular_puntaje`, `calcular_puntaje_por_distancia` ni el mecanismo de temporizador.

**Non-Goals:**
- No se cambia la curva de puntuación por distancia (suelo, máximo, escala) ni el bonus por rapidez.
- No se cambia el desbloqueo de temáticas por posición/estrellas (`panel-topics-form`), que es independiente del camino.
- No hay rediseño visual de la app: solo cambia qué identificador usa para una parada.

## Decisions

### D1: `niveles` y `nivel_desafios` se eliminan; `camino` absorbe su configuración
Sin curación manual, un "nivel" deja de aportar nada que no sea posición + temática + dificultad + overrides opcionales. En vez de mantener `niveles` como capa intermedia vacía de contenido propio, `camino` gana las columnas: `tematica_id` (FK `tematicas`), `dificultad` (enum), `nombre` (nullable), `activo` (bool, default true), y overrides nullable `preguntas_por_partida`, `segundos_por_desafio`, `puntaje_minimo_superar`, `umbral_estrella_2`, `umbral_estrella_3` (NULL = usa el valor de `dificultad_defaults` para esa dificultad). `umbral_estrella_1` sigue sin campo propio: se deriva siempre como igual a `puntaje_minimo_superar` efectivo (default u override), igual que hace hoy `panel-level-detail`.
- Alternativa considerada: mantener `niveles` como tabla con `tematica_id`+`dificultad` y que `camino.nivel_id` siga apuntando ahí. Rechazada: mantendría una entidad intermedia sin curación propia que solo añade una tabla y un join más a mantener, sin beneficio — una parada de camino ya es 1:1 con su temática+dificultad+overrides.

### D2: Las FKs que hoy apuntan a `niveles.id` pasan a apuntar a `camino.id`
`intentos_nivel.nivel_id`, `progreso_usuario_nivel.nivel_id` se renombran a `camino_id` y su FK pasa a `camino(id)`. Se opta por renombrar la columna (no solo la FK) porque mantener el nombre `nivel_id` apuntando a `camino` sería confuso para cualquiera que lea el esquema después de este cambio.
- Alternativa considerada: no renombrar la columna para minimizar el diff en RPCs/policies existentes. Rechazada: el nombre pasaría a mentir sobre lo que referencia de forma permanente; el coste de renombrar ahora es menor que el de confundir a cualquiera que toque este esquema en el futuro.
- Los nombres de tabla (`intentos_nivel`, `progreso_usuario_nivel`, `nivel_id` en RLS ya escritas) SÍ se mantienen tal cual: renombrar las tablas obligaría a recrear políticas RLS, vistas (`camino_jugador`, `desafios_para_jugar`) y referencias en tres capas sin aportar claridad adicional sobre renombrar solo la FK.

### D3: Catálogo de dificultad como `enum` de Postgres, valores por defecto en tabla `dificultad_defaults`
`create type dificultad as enum ('facil','normal','intermedio','dificil','muy_dificil')`. Tabla `dificultad_defaults` con `dificultad` como PK (una fila por valor, sembradas en la propia migración) y columnas `preguntas_por_partida`, `segundos_por_desafio`, `puntaje_minimo_superar`, `umbral_estrella_2`, `umbral_estrella_3` (todas `not null`). Editable desde el panel (nueva pantalla `difficulty-defaults`); lectura pública para autenticados igual que `niveles` hoy, escritura restringida a `is_admin()`.
- Valores sembrados (justificación completa en proposal.md): base = preguntas_por_partida × 5000 (máximo puro por distancia, sin bonus de rapidez, para que superar una parada no dependa de la velocidad de respuesta); % exigido crece geométricamente por dificultad (ratio ×1.172): 45/53/62/72/85 %. Umbrales de estrella 2 y 3 interpolados entre el mínimo y ese máximo al 50 % y 85 % del rango restante:

| Dificultad | Preguntas | Segundos | Mínimo | Umbral★2 | Umbral★3 |
|---|---|---|---|---|---|
| Fácil | 8 | 90 | 18000 | 29000 | 36700 |
| Normal | 8 | 75 | 21200 | 30600 | 37180 |
| Intermedio | 6 | 60 | 18600 | 24300 | 28290 |
| Difícil | 6 | 45 | 21600 | 25800 | 28740 |
| Muy difícil | 5 | 30 | 21250 | 23125 | 24438 |

### D4: `desafios.dificultad` es `not null`; las preguntas existentes se etiquetan `'normal'` al migrar
Toda pregunta nueva exige dificultad explícita en el formulario del panel. Las preguntas ya existentes (creadas antes de este cambio) no tienen dato de dificultad real, así que la migración las etiqueta todas como `'normal'` por convención (punto de partida neutro, editable después fila a fila desde el panel).

### D5: Migración de `camino`/`niveles` existentes: cada parada conserva su configuración como override explícito
Por cada fila de `camino` (vía su `nivel_id` actual), se crea la fila migrada con `tematica_id` del nivel, `dificultad = 'normal'` (consecuencia directa de D4: todas las preguntas ya existentes quedan en 'normal'), y **overrides explícitos** copiados 1:1 desde el nivel: `preguntas_por_partida`, `segundos_por_desafio`, `puntaje_minimo_superar`, `umbral_estrella_2`, `umbral_estrella_3`. Así el comportamiento del camino ya publicado no cambia el día del despliegue — nada depende todavía de `dificultad_defaults` hasta que un admin quite un override a propósito.
- **Riesgo inherente al rediseño (no un bug de la migración)**: si una temática tenía varios niveles curados con preguntas distintas, tras migrar sus paradas quedan todas en el mismo pool (`tematica_id` + `'normal'`) en vez de en listas independientes — es la consecuencia esperada de sustituir curación manual por pool automático. Se documenta en el proposal y se recomienda retiquetar preguntas con dificultades reales pronto tras el despliegue para volver a diferenciar esas paradas.
- Alternativa considerada: intentar inferir la dificultad real de cada nivel migrado a partir de su `puntaje_minimo_superar` relativo (comparándolo contra el resto). Rechazada: es una heurística sin dato real detrás (las preguntas no estaban etiquetadas), añadiría falsa precisión y complicaría la migración sin necesidad — los overrides ya preservan el comportamiento exacto.

### D6: RPC de arranque de intento se renombra a `iniciar_intento_parada(p_camino_id uuid)`
Reemplaza a `iniciar_intento_nivel(nivel_id)`. Resuelve `tematica_id`+`dificultad` efectivos de la parada (con overrides), sortea `preguntas_por_partida` desafíos entre `desafios_para_jugar` filtrados por esa temática+dificultad y `activo`, y persiste la selección en `intento_desafios` igual que hoy. Se renombra porque "nivel" deja de existir como concepto y el parámetro ya no es un `nivel_id`.
- Impacto de código ya existente a actualizar: `app/lib/services/camino_gateway.dart` (llama a la RPC actual) y cualquier RPC/vista que haga `join niveles` (`marcar_desafio_mostrado`'s trigger, `respuestas_desafio_calcular_antes_de_insertar`, el cierre de intento de `level-progression`, `camino_jugador`).

### D1b: `desafios` gana `tematica_id` propio (no existía)
Hoy `desafios` no tiene `tematica_id`: su temática se deducía indirectamente de a qué `niveles` estuviera asignada vía `nivel_desafios`, y una misma pregunta podía en teoría estar asignada a niveles de temáticas distintas. En el nuevo modelo el pool de una parada se resuelve por `tematica_id` + `dificultad` directamente sobre `desafios`, así que `desafios` necesita su propia columna `tematica_id` (FK a `tematicas`, `not null` para altas nuevas) y el formulario de preguntas del panel gana un selector de temática (hoy no existe, ver `panel-questions-form`).
- **Migración de preguntas existentes**: por cada desafío, se backfillea `tematica_id` desde su primera asignación en `nivel_desafios` (por `orden` de nivel más bajo, como desempate determinista). Un desafío nunca asignado a ningún nivel no tiene de dónde inferir su temática — la migración deja constancia de esos casos (query de auditoría) para que un admin les asigne temática manualmente antes de poder marcarlos `activo` en el nuevo modelo.
- **Caso ya señalado en D5**: si un desafío estaba asignado a niveles de temáticas distintas, la migración se queda con la primera y registra el resto como aviso — es un caso raro (la reutilización entre temáticas nunca fue el uso previsto) y no bloquea el despliegue.

### D7: `panel-levels-listing` y `panel-level-detail` se retiran
Sin curación manual no queda nada que gestionar en esas pantallas: la configuración de dificultad vive en `difficulty-defaults` y los overrides por parada se editan directamente desde `panel-path-listing` (que ya lista/edita cada posición del camino).

## Risks / Trade-offs

- [Riesgo] Cambiar el nombre de columna `nivel_id` → `camino_id` y el de la RPC `iniciar_intento_nivel` → `iniciar_intento_parada` rompe cualquier llamada existente desde `app/` y `panel/` → Mitigación: `tasks.md` incluye localizar y actualizar todos los call sites (Flutter `camino_gateway.dart`, cualquier hook/RPC del panel) en el mismo cambio, antes de desplegar.
- [Riesgo] Colapso de pools cuando varios niveles migrados de la misma temática comparten `'normal'` (ver D5) → Mitigación: documentado como consecuencia esperada; recomendar retiquetado post-despliegue, no bloqueante para el despliegue en sí.
- [Riesgo] Migración es de un solo sentido (no hay vuelta a `niveles`/`nivel_desafios` una vez borrados) → Mitigación: la migración de Supabase queda versionada (rollback = restaurar backup previo, como cualquier migración destructiva de este proyecto); no se prevé rollback in-place.
- [Trade-off] Se acepta un `camino` "más gordo" (con columnas de configuración que antes vivían en `niveles`) en vez de mantener dos tablas — ver D1: se prioriza simplicidad de una sola entidad "parada" sobre la separación conceptual previa.

## Migration Plan

1. Migración SQL: crear `enum dificultad`, tabla `dificultad_defaults` (sembrada), añadir `desafios.dificultad not null default 'normal'` (luego quitar el default para altas futuras), añadir columnas nuevas a `camino`.
2. Migración de datos: poblar las columnas nuevas de `camino` desde cada `niveles` referenciado (D5), renombrar `nivel_id`→`camino_id` en `intentos_nivel`/`progreso_usuario_nivel` y repuntar sus FKs a `camino(id)`.
3. Reescribir RPCs/vistas afectadas (`iniciar_intento_parada`, trigger de `respuestas_desafio`, cierre de intento, `camino_jugador`) y su RLS.
4. Borrar `nivel_desafios` y `niveles` una vez migrados los datos y actualizadas todas las referencias.
5. Actualizar `app/lib/services/camino_gateway.dart` y las pantallas del panel (nuevo selector de dificultad, nueva pantalla `difficulty-defaults`, `panel-path-listing` ampliado, retirada de `panel-levels-listing`/`panel-level-detail`).
6. Sin rollback in-place: si algo falla tras desplegar, se restaura desde el backup de Supabase previo a la migración (destructiva por diseño, igual que otras migraciones de este proyecto).

## Open Questions

- Umbrales de estrella exactos (D3) son un punto de partida razonado, no una cifra de producto ya validada como la puntuación mínima — confirmar o ajustar durante `/execute` si el usuario lo pide al probar en local.
