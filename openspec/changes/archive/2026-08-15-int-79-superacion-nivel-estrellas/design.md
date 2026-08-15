## Context

INT-74 ya dejó todas las columnas que esta tarea necesita:
`intentos_nivel.puntaje_total/superado/estrellas_obtenidas` (default
0/false/0) y `progreso_usuario_nivel` completa (`mejor_puntaje`,
`mejores_estrellas`, `desbloqueado`), pero nada las escribe todavía más allá
de sus defaults. INT-78 dejó `respuestas_desafio.puntos` calculado y
persistido de forma fiable por desafío — esta tarea agrega esos puntos por
intento.

`desafios` no tiene `nivel_id` (D3 de INT-74, exclusividad por CHECK): la
pertenencia de un desafío a un nivel vive solo en `nivel_desafios`. Esto
importa aquí porque `responder_desafio` (INT-78) no valida que el
`desafio_id` recibido pertenezca al nivel del intento — solo que el desafío
exista. Cualquier agregación que sume "todas las `respuestas_desafio` del
intento" sin pasar por `nivel_desafios` heredaría ese hueco.

A diferencia de INT-78, aquí no hace falta leer ninguna columna que la RLS
de INT-77 esconda del jugador: `tematicas`/`niveles`/`nivel_desafios` son de
lectura pública para autenticados, y `intentos_nivel`/`respuestas_desafio`/
`progreso_usuario_nivel` ya son legibles/escribibles por su propio dueño.

## Goals / Non-Goals

**Goals:**

- Cerrar un intento agregando el puntaje real del nivel (vía
  `nivel_desafios`, no vía todas las respuestas del intento a ciegas).
- Decidir `superado` y `estrellas_obtenidas` (1-3) de forma determinista.
- Mantener `progreso_usuario_nivel` como el mejor resultado histórico, sin
  que rejugar un nivel ya superado pueda empeorarlo.
- Desbloquear el siguiente nivel de la temática al superar, y la siguiente
  temática al acumular estrellas suficientes dentro de la temática actual.

**Non-Goals:**

- Corregir que `responder_desafio` no valide que el `desafio_id` pertenezca
  al nivel del intento — se compensa aquí filtrando por `nivel_desafios` al
  agregar, pero no se toca la RPC de INT-78. Si se decide cerrar ese hueco
  en origen, es una tarea aparte.
- Qué desbloquea el primer nivel de la primera temática para un jugador sin
  intentos previos (seed, trigger de alta, u otro ticket — no hay intento
  que dispare esta RPC todavía).
- Límite de intentos: no existe (ya lo garantiza el esquema de INT-74, sin
  unique en `intentos_nivel` por usuario/nivel).

## Decisions

### D1. Agregar vía `nivel_desafios`, no sumando toda `respuestas_desafio` del intento

El propio issue lo pide explícito: "las preguntas que componen un intento
se resuelven a través de `nivel_desafios`". La suma se calcula con:

```sql
select coalesce(sum(rd.puntos), 0)
from respuestas_desafio rd
join nivel_desafios nd
  on nd.desafio_id = rd.desafio_id
 and nd.nivel_id = v_nivel_id
where rd.intento_id = p_intento_id;
```

en vez de `sum(puntos) where intento_id = p_intento_id`. La diferencia
importa: como `responder_desafio` no ata el `desafio_id` al nivel del
intento, un `insert` (directo o vía RPC) con un desafío ajeno al nivel no
debe poder inflar el puntaje del cierre. Filtrar por `nivel_desafios` lo
descarta sin tener que tocar INT-78.

### D2. Cierre exige respuesta completa: todas las filas de `nivel_desafios` del nivel

Antes de calcular nada, se compara `count(distinct rd.desafio_id)` (del
join de D1) contra `count(*)` de `nivel_desafios` para ese `nivel_id`. Si no
coinciden, la función lanza excepción y no escribe nada. Alternativa
descartada: cerrar con lo que haya, tratando las preguntas sin responder
como 0 puntos. Se descarta porque un intento a medias (por ejemplo, la app
se cierra a mitad de partida) no debería poder consumirse como un intento
fallido real — el jugador simplemente no ha terminado, y cerrarlo
penalizaría sin que el jugador lo supiera. La app debe esperar a que el
jugador conteste todos los desafíos del nivel antes de llamar a esta RPC.

### D3. `security invoker`, no `definer`

A diferencia de `responder_desafio` (INT-78, `definer` porque necesita leer
`lat_real`/`lng_real` ocultas por RLS), esta función no lee nada que RLS le
esconda al propio usuario: `niveles`/`tematicas`/`nivel_desafios` son
públicas para autenticados, y las filas de `intentos_nivel`/
`respuestas_desafio`/`progreso_usuario_nivel` que toca son siempre las del
propio `auth.uid()`. Con `security invoker`, la propia RLS de INT-77 ya
impide cerrar el intento de otro usuario (el `select` sobre
`intentos_nivel` de un intento ajeno simplemente no devuelve fila, sin
necesitar una comprobación manual como en INT-78). Menos superficie
`definer` que auditar.

### D4. Umbral de estrellas: superado garantiza mínimo 1, aunque el puntaje quede por debajo de `umbral_estrella_1`

El CHECK de INT-74 solo obliga `puntaje_minimo_superar <= umbral_estrella_1`
(no exige igualdad), así que existe un rango válido de puntaje donde el
nivel queda superado pero por debajo de `umbral_estrella_1`. El issue dice
"si está superado, calcular estrellas (1-3)" — nunca 0 estando superado. Se
resuelve con:

```sql
estrellas := case
  when not v_superado then 0
  when v_puntaje >= umbral_estrella_3 then 3
  when v_puntaje >= umbral_estrella_2 then 2
  else 1
end;
```

Es decir, superar el nivel ya garantiza 1 estrella; `umbral_estrella_1` solo
importa como techo conceptual del diseño de niveles (dato de producto), no
como condición extra de código. Alternativa descartada: exigir
`v_puntaje >= umbral_estrella_1` para dar la primera estrella y permitir 0
estrellas con `superado = true`. Se descarta por contradecir literalmente
el issue.

### D5. `progreso_usuario_nivel` y desbloqueos: upsert monótono con `GREATEST`, siempre (no solo "si mejora")

En vez de comparar el resultado nuevo contra el guardado y decidir si
escribir, el upsert usa `GREATEST`/`OR` en todas las columnas relevantes:

```sql
insert into progreso_usuario_nivel (usuario_id, nivel_id, superado, mejor_puntaje, mejores_estrellas, desbloqueado)
values (auth.uid(), v_nivel_id, v_superado, v_puntaje, v_estrellas, true)
on conflict (usuario_id, nivel_id) do update set
  superado = progreso_usuario_nivel.superado or excluded.superado,
  mejor_puntaje = greatest(progreso_usuario_nivel.mejor_puntaje, excluded.mejor_puntaje),
  mejores_estrellas = greatest(progreso_usuario_nivel.mejores_estrellas, excluded.mejores_estrellas),
  desbloqueado = true,
  actualizado_en = now();
```

Es equivalente a "solo actualiza si mejora" (un `GREATEST` nunca reduce un
valor existente) pero sin una lectura+comparación previa, y hace que la
función sea segura de llamar más de una vez sobre el mismo intento
(reintento de red desde la app, por ejemplo): recalcula el mismo resultado
desde `respuestas_desafio` y el upsert no cambia nada en una segunda
llamada. El mismo patrón (`on conflict ... do update` con `desbloqueado =
true` y el resto sin tocar) se usa para desbloquear el siguiente nivel y la
siguiente temática, evitando pisar un progreso ya existente en esas filas
si el jugador ya las había jugado antes por otra vía.

### D6. Desbloqueo de temática = desbloqueo de su primer nivel

El esquema no tiene un `desbloqueado` propio a nivel de `tematicas` — solo
`progreso_usuario_nivel.desbloqueado` por nivel. "Desbloquear la siguiente
temática" se traduce en upsertear `desbloqueado = true` para
`(auth.uid(), primer_nivel_de_la_siguiente_tematica)` (el nivel con
`orden = 1` de esa temática). El umbral se comprueba sumando
`mejores_estrellas` de `progreso_usuario_nivel` solo entre los niveles de la
temática **actual** (no acumulado global de todas las temáticas jugadas),
que es la lectura literal del issue: "estrellas requeridas acumuladas **en
la temática**".

### D7. Lock de asesoramiento por `(usuario, temática)` antes de decidir el desbloqueo de la siguiente temática

Bajo `READ COMMITTED` (el nivel por defecto), si un mismo usuario cierra a
la vez dos intentos de niveles distintos de la misma temática, cada
transacción calcula la suma de `mejores_estrellas` (D6) leyendo el estado
committeado hasta ese momento — sin ver el `upsert` que la otra
transacción concurrente todavía no ha confirmado. Es un caso real de
"lost update": ambas transacciones pueden ver la suma por debajo del
umbral y ninguna desbloquear la siguiente temática, aunque el total ya
alcanzado (tras que ambas terminen) sí lo cumpla. Se soluciona con
`pg_advisory_xact_lock` justo antes de calcular esa suma, usando como clave
el par `(auth.uid(), tematica_id)`: la segunda transacción en llegar
espera a que la primera termine (haciendo visible su `upsert`) antes de
leer la suma, así que siempre ve el estado completo. Alternativa
descartada: subir la función a `SERIALIZABLE`, que exigiría que la app
maneje reintentos ante fallos de serialización — coste innecesario cuando
el lock de asesoramiento resuelve exactamente esta sección crítica sin
tocar el resto de la función ni el aislamiento de otras RPCs.

## Risks / Trade-offs

- **Cierre exige completitud (D2)** → si la app llama a la RPC antes de que
  el jugador conteste todos los desafíos del nivel, la llamada falla en vez
  de cerrar parcialmente. Es intencional: evita cierres accidentales a
  medias. Mitigación: la app solo debe llamar `cerrar_intento_nivel` tras la
  última respuesta del nivel.
- **No corrige la falta de validación de `nivel_desafios` en
  `responder_desafio`** → un `desafio_id` ajeno al nivel puede seguir
  insertándose en `respuestas_desafio`; esta tarea solo evita que contamine
  el cierre (D1), no lo impide en origen. Mitigación futura: si se decide
  cerrar el hueco, añadir el check directamente en `responder_desafio` (o
  en el trigger de INT-78) en una tarea aparte.
- **Idempotencia sin flag de "cerrado"** → `intentos_nivel` no tiene una
  columna que distinga "nunca cerrado" de "cerrado con 0 puntos". Mitigado
  porque el cálculo es puramente determinista a partir de
  `respuestas_desafio`: cerrar dos veces el mismo intento siempre reescribe
  el mismo resultado, nunca uno distinto.

## Migration Plan

Una migración nueva con la función RPC `cerrar_intento_nivel` (`security
invoker`), sin cambios de esquema (todas las columnas y tablas ya existen
desde INT-74). Aplicada con `supabase db push` contra el proyecto remoto
enlazado.

**Rollback**: `drop function cerrar_intento_nivel` en una migración
inversa, o `supabase db reset --linked` mientras no haya contenido real.
