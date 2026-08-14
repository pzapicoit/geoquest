## Context

`backend/supabase/` está inicializado y vinculado al proyecto remoto
(`xhrntgsdlnwrvwehqfgl`, Postgres 17.6, `eu-west-1`), sin migraciones ni
tablas todavía (INT-73). El flujo es remote-first: sin stack local con
Docker, las migraciones se escriben con `supabase migration new` y se
aplican con `supabase db push` directamente contra el proyecto real (decisión
D6 de INT-73). `gen_random_uuid()` es nativo desde Postgres 13, así que no
hace falta `CREATE EXTENSION pgcrypto`.

El issue describe ocho tablas a alto nivel. Varios tickets ya en Backlog
acotan qué NO entra aquí:

- INT-77 habilita RLS y escribe las políticas.
- INT-78 calcula distancia/puntaje (Haversine o PostGIS — decisión suya).
- INT-79 decide cómo se "cierra" un `intento_nivel` y cómo se desbloquean
  niveles/temáticas.
- INT-75 crea el trigger que inserta en `profiles` al registrarse.
- INT-95 crea la vista `desafios_para_jugar` y el RPC
  `iniciar_intento_nivel`, que es lo que en la práctica inserta filas en
  `intentos_nivel`.

Esta tarea define únicamente la forma de los datos: tablas, tipos, FKs y
constraints que esos tickets van a necesitar.

## Goals / Non-Goals

**Goals:**

- Las ocho tablas del issue, con columnas, tipos y constraints suficientes
  para que ningún ticket posterior tenga que alterar la forma básica del
  esquema (solo añadir funciones, vistas, políticas o triggers encima).
- Integridad referencial completa entre las ocho tablas.
- Migración única, versionada y aplicada al proyecto remoto.

**Non-Goals:**

- RLS y políticas (INT-77). Las tablas quedan sin RLS habilitado.
- Funciones/RPC de cálculo o de negocio (INT-78, INT-79, INT-87, INT-95,
  INT-96).
- Trigger de creación de `profiles` al registrarse (INT-75). La tabla existe;
  quién inserta en ella no es de esta tarea.
- Datos de contenido (temáticas/niveles/desafíos reales) — los crea el panel,
  que todavía no existe.
- Elegir Haversine vs PostGIS — se guardan `lat`/`lng` como columnas planas
  (`double precision`) para que INT-78 decida sin que este esquema se lo
  imponga.

## Decisions

### D1. `profiles.id` es el propio `auth.users.id`, sin columna "usuario"

El issue lista la tabla como "(usuario, nombre, avatar, role)". Se interpreta
"usuario" como la identidad de la fila, no como una columna de texto: la PK
de `profiles` es `id uuid references auth.users(id)`. Quién inserta esa fila
(trigger de INT-75) es responsabilidad de otro ticket; aquí solo se define la
tabla y su enlace 1:1 con `auth.users`.

### D2. Enums para `role` y `tipo` en vez de `text` + `CHECK`

`rol_usuario` (`admin`, `jugador`) y `tipo_desafio` (`imagen`,
`pregunta_texto`, `video`) son conjuntos cerrados y estables — el propio
issue los enumera explícitamente. Un tipo `ENUM` de Postgres documenta el
conjunto válido en el catálogo y es más barato que `text` en las tablas de
mayor volumen (`respuestas_desafio` hereda `tipo_desafio` indirectamente vía
`desafios`).

*Alternativa considerada:* `text` con `CHECK (role IN (...))`. Descartada:
mismo resultado con menos claridad en `\d` y en cualquier introspección del
esquema.

### D3. Exclusividad de columnas en `desafios` vía `CHECK`, no vía tres tablas separadas

`desafios` tiene `imagen_url`, `video_url` y `texto_pregunta` como columnas
nullable de una sola tabla, con:

```sql
check (
  (tipo = 'imagen'          and imagen_url     is not null and video_url is null and texto_pregunta is null) or
  (tipo = 'video'           and video_url      is not null and imagen_url is null and texto_pregunta is null) or
  (tipo = 'pregunta_texto'  and texto_pregunta is not null and imagen_url is null and video_url is null)
)
```

*Alternativa considerada:* una tabla `desafios` genérica más tres tablas de
detalle (`desafios_imagen`, `desafios_video`, `desafios_texto`) con FK 1:1.
Correcta en teoría relacional pura, pero `nivel_desafios` referenciaría un
`desafio_id` ambiguo entre tres tablas, y toda consulta de "el banco de
desafíos" necesitaría un `UNION` o una vista. El `CHECK` da la misma garantía
de exclusividad con una sola tabla y una sola FK desde `nivel_desafios`.

### D4. `nivel_desafios` con PK compuesta `(nivel_id, desafio_id)`

Una pregunta no puede repetirse dentro del mismo nivel, pero sí reutilizarse
en niveles distintos (issue explícito). La PK compuesta lo garantiza sin
constraint adicional. `UNIQUE (nivel_id, orden)` evita que dos preguntas
compartan la misma posición dentro de un nivel.

### D5. `ON DELETE RESTRICT` desde `nivel_desafios` y `respuestas_desafio` hacia `desafios`

Un desafío ya usado en un nivel, o ya respondido por algún jugador, no se
puede borrar en cascada sin perder historial de partidas o romper un nivel en
uso. Borrar un `desafio` exige primero desasignarlo de todos los niveles (y,
en la práctica, con historial de respuestas, la vía real es desactivarlo con
`activo = false`, no borrarlo). El resto de FKs (`niveles → tematicas`,
`intentos_nivel → niveles/profiles`, `respuestas_desafio → intentos_nivel`,
`progreso_usuario_nivel → profiles/niveles`) usan `ON DELETE CASCADE`: si se
borra una temática o un perfil, su descendencia deja de tener sentido por sí
sola.

### D6. `progreso_usuario_nivel` se crea de forma perezosa, no se pre-siembra

La tabla tiene PK `(usuario_id, nivel_id)` — una fila por jugador y nivel. No
se crea una fila para cada combinación posible al registrarse o al crear un
nivel nuevo (evita un `INSERT` de N usuarios × M niveles en cada alta de
cualquiera de los dos). Se asume que INT-79 (o INT-96 al leer) trata la
ausencia de fila como "sin progreso, no superado, 0 estrellas", y que solo el
primer nivel de la primera temática se considera desbloqueado sin
necesidad de fila — el resto de desbloqueos se derivan de estrellas
acumuladas en la temática anterior (columna `tematicas.estrellas_requeridas`).

### D7. `lat`/`lng` como `double precision`, sin PostGIS

Ver Non-Goals: INT-78 decide la fórmula de distancia. Columnas planas
mantienen esa decisión abierta; si INT-78 opta por PostGIS puede añadir una
columna `geography` generada o una función que lea las columnas planas, sin
tocar esta migración.

## Risks / Trade-offs

- **Sin RLS entre esta tarea e INT-77** → mientras no se apliquen políticas,
  las tablas no quedan expuestas por defecto: `backend/supabase/config.toml`
  ya fija el comportamiento nuevo de Supabase (no auto-exponer tablas nuevas
  a los roles `anon`/`authenticated` sin grants explícitos). El riesgo real
  es que alguien añada un grant manual antes de que existan políticas — se
  mitiga igual que en INT-73: todo cambio de esquema pasa por migración
  versionada, nunca a mano.
- **Ambigüedad sobre "cerrar" un `intento_nivel`** → el issue solo pide una
  columna `fecha`; no hay columna de estado que distinga un intento en curso
  de uno cerrado. `puntaje_total = 0, superado = false` es indistinguible
  entre "todavía jugando" y "perdió con 0 puntos". Se deja así a propósito:
  INT-79, al implementar el RPC que cierra el intento, es quien mejor sabe
  si necesita una columna de estado o si le basta con la fila apareciendo ya
  con puntaje final. Añadirla ahora sería adivinar su implementación.
- **`progreso_usuario_nivel` perezosa (D6) traslada complejidad a
  INT-79/INT-96** → ambos tickets ya mencionan explícitamente "calcular
  estrellas acumuladas" y "desbloqueado", así que ya contaban con derivar
  este estado; no es una carga nueva que este diseño les añada.

## Migration Plan

Una sola migración (`create_game_schema`) aplicada con `supabase db push`
contra el proyecto remoto. No hay datos previos que migrar — el esquema
actual está vacío.

**Rollback:** `supabase migration repair` para marcar la migración como
revertida y una migración inversa que haga `DROP TABLE` en orden inverso de
dependencias (o `supabase db reset --linked` si no hay contenido real creado
todavía, que es el caso).

## Open Questions

- ¿Necesita `intentos_nivel` una columna de estado explícita
  (`en_curso`/`cerrado`) antes de que INT-79 implemente el cierre? Ver Risk
  correspondiente — se deja para que lo decida ese ticket.
- ¿`tematicas.imagen_portada` debería aceptar `NULL` mientras no exista panel
  para subir la imagen? Se deja `NOT NULL` porque el panel (INT-85) es quien
  crea temáticas y siempre podrá exigir la imagen en el formulario; no hay
  inserción intermedia sin panel que necesite el hueco.
