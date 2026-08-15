## Context

`respuestas_desafio` (INT-74) ya tiene `lat_adivinada`, `lng_adivinada`,
`distancia_km` y `puntos` como columnas `not null` con `check >= 0`. La RLS
de INT-77 (`respuestas_desafio_insert_own`) permite a un usuario autenticado
insertar una fila para su propio `intento_id`, pero **no restringe qué
valores puede llevar `distancia_km`/`puntos`** — solo comprueba la
pertenencia del intento. Hoy, sin esta tarea, un cliente podría insertar
directamente vía PostgREST con cualquier puntaje inventado.

`desafios` no tiene policy de `select` para jugadores (a propósito, INT-77):
un jugador nunca puede leer `lat_real`/`lng_real` por su cuenta. Cualquier
función que necesite esas columnas para calcular la distancia tiene que
saltarse esa RLS deliberadamente (`security definer`), y solo para esa
lectura puntual — nunca devolviendo esas coordenadas al cliente.

D7 de INT-74 dejó `lat`/`lng` como `double precision` planas explícitamente
para que esta tarea decida Haversine vs PostGIS sin migrar nada.

## Goals / Non-Goals

**Goals:**

- Calcular distancia (km) y puntaje de forma determinista y en servidor.
- Exponer una RPC (`responder_desafio`) como único punto de entrada
  recomendado para que la app registre la respuesta de un jugador.
- Garantizar que `distancia_km`/`puntos` en `respuestas_desafio` reflejan
  siempre el cálculo del servidor, sin importar la vía de inserción.
- No filtrar nunca `lat_real`/`lng_real` al cliente a través de esta RPC.

**Non-Goals:**

- Agregar `puntaje_total` en `intentos_nivel` o decidir cuándo se "cierra"
  un intento — es INT-79.
- PostGIS: se descarta explícitamente (ver D1). Si en el futuro hace falta
  (p. ej. distancias sobre rutas, no línea recta), es una tarea aparte.
- Balancear la fórmula de puntaje con datos reales de juego — las
  constantes quedan aisladas y documentadas para que el panel/producto las
  ajuste sin tocar la lógica.

## Decisions

### D1. Haversine en SQL puro, sin extensión PostGIS

Habilitar PostGIS añade una extensión, un tipo `geography` y una curva de
aprendizaje para un cálculo que Haversine resuelve en una función SQL de
~10 líneas con precisión más que suficiente (error <0.5% frente a distancia
geodésica real, irrelevante para puntuar un juego de adivinar ubicación).
Mantiene además la decisión D7 de INT-74 (columnas planas) sin abrir una
migración de esquema. Si más adelante se necesita PostGIS por otro motivo
(rutas, índices espaciales), se añade entonces sin que esta función tenga
que cambiar de forma — sigue recibiendo 4 `double precision` y devolviendo
uno.

### D2. Puntaje: decaimiento lineal con umbral, no exponencial

El issue pide "puntaje máximo si la distancia es ~0, decreciente hasta 0 a
partir de cierto umbral" — es decir, un cero exacto a partir de una
distancia dada, no una asíntota. Un decaimiento exponencial (estilo
GeoGuessr clásico) nunca llega a 0 limpio. Se usa:

```
puntos = round(greatest(0, puntaje_maximo * (1 - distancia_km / distancia_umbral_km)))
```

Constantes elegidas como punto de partida (temática de monumentos del
mundo, ver `Recursos/`, juego a escala global): `puntaje_maximo = 5000`,
`distancia_umbral_km = 2000`. Ambas quedan como constantes al principio de
`calcular_puntaje`, documentadas con un comentario, para que se ajusten sin
tocar el resto de la función. Esto es un punto de partida razonable, no un
valor validado con playtesting — ver nota de producto en la respuesta al
usuario.

### D3. Una única RPC `security definer` en vez de RPC invoker + helper separado

Se evaluaron dos formas de leer `lat_real`/`lng_real` (que RLS esconde del
jugador):

1. **RPC `security invoker`** que llama a una función auxiliar `security
   definer` solo para las coordenadas.
2. **Una única función `security definer`** (`responder_desafio`) que hace
   todo: valida a mano que `intento_id` pertenece a `auth.uid()`, lee las
   coordenadas reales, calcula, e inserta.

Se elige (2). Con (1), la función auxiliar de coordenadas tendría que
existir como objeto propio en `public`, y aunque no se le conceda `execute`
a `authenticated`, divide la lógica sensible (anti-trampa) en dos objetos
que hay que mantener sincronizados. Con (2) hay un único punto donde se
otorga acceso elevado y un único lugar que auditar: si mañana cambia la
policy de intentos, solo hay que revisar esta función. El coste es que
`responder_desafio` **debe** repetir a mano la comprobación de propiedad del
intento que la RLS ya hace para inserts directos (una función `security
definer` no pasa por RLS al escribir), así que esa comprobación explícita
es obligatoria, no opcional — se cubre con un test de caso límite (ver
Risks).

### D4. Trigger `before insert` que siempre recalcula, incluso llamando desde la RPC

Aunque `responder_desafio` sea el camino recomendado, la policy de INT-77
sigue permitiendo un `insert` directo en `respuestas_desafio` con
`distancia_km`/`puntos` arbitrarios — esa policy no es de esta tarea y no se
toca (ver Non-Goals de INT-74/INT-77: cambiarla es decisión de RLS, no de
cálculo). Un trigger `before insert` (`security definer`, igual que
`responder_desafio`, porque también necesita leer `lat_real`/`lng_real`)
que recalcula `distancia_km`/`puntos` a partir de `lat_adivinada`/
`lng_adivinada` y el `desafio_id` de la fila, **sobrescribiendo** cualquier
valor recibido, hace que el dato final en la tabla sea siempre el cálculo
del servidor sin importar si el insert vino de la RPC o de un insert
directo. La propia RPC puede insertar con `distancia_km`/`puntos`
provisionales (o directamente delegar el cálculo al trigger) — el trigger
es la garantía real, la RPC es la interfaz cómoda.

Alternativa descartada: no poner trigger y confiar en que la app siempre
use la RPC. Se descarta porque "guardar automáticamente" en el issue se lee
como una garantía del sistema, no como una convención de cliente bien
portado — y el coste del trigger es bajo (misma lógica que ya existe en la
RPC, factorizada en las dos funciones de cálculo).

## Risks / Trade-offs

- **`security definer` + lógica de autorización a mano** → si
  `responder_desafio` olvidara comprobar que `intento_id` pertenece a
  `auth.uid()`, cualquier usuario podría insertar respuestas en el intento
  de otro. Mitigado con un caso límite explícito en pruebas manuales:
  intentar llamar a la RPC con un `intento_id` ajeno debe fallar.
- **Constantes de puntaje sin validar con datos reales** → `puntaje_maximo`
  y `distancia_umbral_km` son una elección razonable pero arbitraria.
  Mitigado quedando aisladas y comentadas en `calcular_puntaje` para
  ajustarse en una migración pequeña, sin tocar `responder_desafio` ni el
  trigger.
- **Trigger silencioso** → si alguien inserta directamente esperando que su
  `distancia_km` se respete, se llevará una sorpresa (se sobrescribe sin
  avisar). Es intencional (D4): es exactamente la garantía que se busca.

## Migration Plan

Una migración nueva (`calcular_distancia_puntaje` o similar) con: las dos
funciones de cálculo, la función RPC, el trigger y su `create trigger`.
Aplicada con `supabase db push` contra el proyecto remoto enlazado (no hay
stack local, D6 de INT-73). No transforma datos existentes — no hay filas
en `respuestas_desafio` todavía.

**Rollback**: `drop trigger`, `drop function` de las tres funciones, en una
migración inversa, o `supabase db reset --linked` mientras no haya contenido
real (caso actual).
