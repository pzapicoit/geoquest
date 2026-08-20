## Context

`desafios.nombre_lugar` es hoy el único texto que nombra el objetivo, y arrastra
dos papeles a la vez: el punto exacto de la respuesta y su ubicación en el mapa
administrativo. El banco real (135 filas) va de `Coliseo de Roma, Italia` a
`Parque de bomberos Hook & Ladder 8, Tribeca, Nueva York`.

Ese campo tiene, además del revelado, tres consumidores vivos que no piden una
ciudad sino el punto concreto:

| Consumidor | Para qué usa `nombre_lugar` |
|---|---|
| `panel/src/lib/dashboard.ts` | etiqueta de las alertas de contenido (`{nombre_lugar} ({tipo})`) |
| `panel/src/lib/iaPreguntas.ts` → `duplicadosLugar.ts` | deduplicación de candidatos por nombre normalizado |
| `panel/src/pages/Preguntas.tsx` | búsqueda del listado, combinada con `nombre` |

Tras INT-121 la hoja de resultado pinta `nombre_lugar` a **una línea con
ellipsis** (`maxLines: 1`), así que los valores largos se cortan exactamente en
la parte que localiza el objetivo.

Precedente directo: `desafios.pais` (INT-119) resolvió el mismo tipo de problema
—un dato del objetivo que `nombre_lugar` no modela— con una columna nullable, un
campo opcional en el formulario del panel y un backfill puntual del banco.

## Goals / Non-Goals

**Goals:**

- Que el revelado nombre siempre un sitio legible de un vistazo, sin truncarse.
- Modelar la ciudad como dato propio del objetivo, disponible para el panel y
  para lo que venga después, no solo como texto de una pantalla.
- Que el contenido creado con IA nazca con ciudad **y país**, en vez de acumular
  la misma deuda que hubo que pagar a mano con `pais`.
- No romper nada de lo que hoy depende de `nombre_lugar`.

**Non-Goals:**

- Un comodín de ciudad. La ciudad *es* prácticamente la respuesta en un mapa sin
  topónimos; revelarla a mitad de partida es otro juego, no otro comodín.
- Tocar la deduplicación de candidatos. Ver D9.
- Normalizar `nombre_lugar` ni recortarle el país que muchos valores ya llevan
  dentro. Queda como está.
- Exponer la ciudad antes de responder, en ninguna superficie.

## Decisions

**D1 — Columna nueva `ciudad`, no reescribir ni renombrar `nombre_lugar`.**
Decidido con el usuario entre tres opciones. Reescribir `nombre_lugar` para que
contuviera la ciudad habría dejado sin punto exacto a los tres consumidores de la
tabla de arriba: las alertas del dashboard pasarían a decir "Nueva York (imagen)"
en tres filas distintas, y la deduplicación perdería la señal de nombre que hoy
distingue dos monumentos de la misma ciudad. Renombrar la columna añadía el ruido
de tocar RPC, app, panel y cuatro specs sin ganar nada que la columna nueva no
diera. La columna es nullable y no rompe ningún `insert` existente.

**D2 — `responder_desafio` se actualiza con `create or replace`, sin `drop`.**
La firma no cambia: la función ya devuelve `jsonb` desde INT-93, y añadir una
clave al objeto no es un cambio de tipo de retorno. Esto la diferencia de INT-93,
que sí necesitó `drop` porque pasaba de devolver una fila a devolver `jsonb`. Se
parte de la definición vigente
(`20260818122000_dificultad_camino_rpcs_vistas.sql`, la última de la cadena) y se
le añade `ciudad` al `select` y al `jsonb_build_object`. Copiar la definición
entera es obligado, no una elección: `create or replace` sustituye el cuerpo
completo, así que omitir cualquier parte del cuerpo vigente (el bonus por
rapidez, el desglose de puntaje, la validación del pin nulo) sería una
regresión silenciosa.

**D3 — La ciudad no necesita ninguna defensa nueva de RLS.**
`desafios` no tiene policy de `select` para jugadores desde INT-77 —solo
`is_admin()`—, y `desafios_para_jugar` enumera sus columnas de forma explícita.
Añadir una columna a la tabla no la expone a nadie. La única disciplina que hace
falta es **no** meterla en la vista ni en el `jsonb` de
`iniciar_intento_parada`, y eso es lo que fijan los escenarios nuevos de
`challenge-play`: la garantía se convierte en requisito verificable en vez de
depender de que nadie la añada por comodidad más adelante.

**D4 — El texto del rótulo se resuelve una sola vez en la pantalla.**
`ciudad ?? nombre_lugar`, calculado en un solo punto y consumido tanto por la
hoja de resultado como por `revelarUbicacion(...)` (el rótulo del pin sobre el
mapa). La alternativa —resolver el fallback en cada punto de uso— deja dos sitios
que pueden divergir, y el síntoma sería el peor posible: el mapa nombrando el
sitio de una manera y la hoja de otra, en la misma pantalla y al mismo tiempo.

**D5 — `ciudad` viaja a la app como `String?`, no como `String` con `''`.**
El mapeo de `nivel_juego_gateway.dart` distingue hoy campos exigidos (`_texto`,
que lanza si falta) de opcionales (`_decimalOpcional`). `ciudad` es del segundo
grupo y necesita un `_textoOpcional` que no existe todavía: hay que añadirlo. Un
`''` por defecto sería peor que un `null` porque el fallback a `nombre_lugar` se
volvería una comparación con cadena vacía repartida por la UI, en vez de una
ausencia explícita en el modelo.

**D6 — El backfill va como migración de datos versionada, no vía REST.**
Esto **se aparta** de cómo se hizo el backfill de `pais` (INT-119 delta-2, que lo
aplicó "vía REST con la clave de servicio, sin migración"). El motivo es que el
banco de contenido vive solo en el proyecto remoto —`seed.sql` tiene 21 líneas— y
el README documenta `supabase db reset --linked` como camino normal de reset:
un backfill aplicado por REST se evapora en el siguiente reset y nadie se
entera. Una migración de datos, como la de INT-116
(`20260819181000_migracion_datos_nombre_objetivo_global.sql`), sobrevive, se
revisa en el PR y queda como registro de por qué cada fila tiene el valor que
tiene. En una base recién reseteada las `update` no encuentran filas y son
no-ops inocuos.

**D7 — Los valores del backfill los determina el modelo ahora, no una
integración de IA en tiempo de ejecución.** Mismo criterio que D3 de INT-119
delta-2: los 135 desafíos traen `nombre`/`nombre_lugar`/`lat_real`/`lng_real`
suficientes para determinar la ciudad, y montar una Edge Function nueva con su
secreto y su coste para un backfill de una sola vez no se paga. La verificación
SHALL cruzar coordenadas y no solo el nombre — el precedente de INT-119 es
"Museo de Antioquía", cuyas coordenadas son de Antakya (Turquía) y no de Medellín
(Colombia). Lo que quede ambiguo se deja en `NULL`, que degrada a `nombre_lugar`,
en vez de escribir un dato plausible pero falso.

**D8 — `pais` entra en el generador junto a `ciudad`.**
No lo pedía el enunciado, pero hoy el generador no rellena `pais`, así que toda
pregunta creada con IA nace con el comodín de país (INT-119) muerto para ella. Es
el mismo prompt, el mismo esquema de respuesta y la misma llamada a OpenAI: el
coste marginal es cero y dejarlo fuera sería programar el siguiente backfill a
mano. La única regla del prompt que se refuerza es la que ya existía: la
descripción no nombra la respuesta, ni su país, ni su ciudad, ni el gentilicio de
ninguno.

**D9 — La ciudad no entra en la deduplicación de candidatos.**
`duplicadosLugar.ts` cruza nombre normalizado y cercanía de coordenadas (umbral
10 km). La ciudad no es señal de duplicado: el Coliseo, el Panteón y la Fontana
di Trevi comparten ciudad y están dentro del umbral de kilómetros, y es el nombre
lo que los distingue. Meter la ciudad en la comparación convertiría "otra
pregunta de Roma" en "duplicado".

**D10 — La ciudad vacía se persiste como `NULL`, no como `''`.**
Mismo tratamiento que `pais` en `preguntaForm.ts`
(`input.pais?.trim() ? input.pais.trim() : null`). Importa porque `''` es un
valor que la app leería como ciudad válida y rotularía como un hueco en blanco.

**D11 — El paso 2 del wizard muestra la ciudad.**
No basta con persistirla: la ilustración cuesta ~0,04 USD y ~24 s por candidato,
así que el momento de detectar una ciudad equivocada es antes de gastarla, no
después de guardar el lote. Es el mismo argumento por el que ese paso ya muestra
coordenadas y descripción.

## Risks / Trade-offs

- **[Riesgo] El revelado pierde el país en los valores que hoy lo llevan
  dentro.** `Varsovia, Polonia` pasa a leerse `Varsovia`. → Consecuencia
  deliberada de la decisión del usuario (solo la ciudad). El país tiene su propio
  campo y su propio comodín, y componer `ciudad, país` en el rótulo es un cambio
  de una línea si en dispositivo se lee peor de lo esperado.
- **[Riesgo] El backfill se equivoca en una fila ambigua y el jugador lee una
  ciudad falsa.** → Cruce obligatorio con coordenadas (D7), y `NULL` como salida
  cuando la duda no se resuelve: degradar al comportamiento actual siempre es
  mejor que afirmar algo falso. El resultado queda en un fichero de migración
  revisable fila a fila, no en un `update` perdido en un log.
- **[Riesgo] Pedirle al modelo la ciudad como campo aumenta la probabilidad de
  que se le escape en la descripción**, que es la pista del jugador. → La regla
  ya estaba en el prompt y se refuerza explícitamente; y el paso 2 del wizard
  enseña descripción y ciudad juntas, así que la fuga es visible antes de
  guardar.
- **[Riesgo] Divergencia entre el rótulo del pin y el de la hoja.** → D4: un solo
  punto de resolución, y un escenario de spec que fija que los dos textos
  coinciden.
- **[Trade-off] `nombre_lugar` deja de mostrarse en la app**, y se queda como
  dato de administración y de deduplicación. → Aceptado: nunca fue un buen texto
  de una línea, y el panel sigue siendo donde se lee entero.
- **[Riesgo] Copiar el cuerpo de `responder_desafio` para el `create or replace`
  puede perder algo por el camino.** → El diff de la migración se compara contra
  `20260818122000_dificultad_camino_rpcs_vistas.sql` y la única diferencia
  esperada son las tres líneas de `ciudad`; y el revelado se prueba en
  dispositivo con desglose de bonus visible, que es lo que se rompería.

## Migration Plan

1. **Migración de esquema**: `alter table desafios add column ciudad text` y
   `create or replace function responder_desafio(...)` con `ciudad` en el
   revelado. `supabase db push`.
2. **Migración de datos**: `update` por fila con la ciudad determinada. Se aplica
   en el mismo `db push`, después de la de esquema (el orden lo garantiza el
   timestamp del nombre de fichero).
3. **Edge Function**: `supabase functions deploy proponer-lugares`. Compatible
   hacia atrás en un sentido útil — un panel viejo contra la función nueva
   ignora los campos que no conoce; un panel nuevo contra la función vieja
   recibe `ciudad` indefinida y guarda `NULL`, que es exactamente el
   comportamiento de hoy. No hay orden obligatorio de despliegue.
4. **Panel**: despliegue normal a Vercel.
5. **App**: build nueva. Una app vieja contra la RPC nueva ignora la clave
   `ciudad` del `jsonb` y sigue rotulando `nombre_lugar`, así que no hay ventana
   de rotura mientras se propaga.

**Rollback**: la columna se queda (no estorba a nadie) y `responder_desafio`
vuelve a la definición de `20260818122000` con otro `create or replace`. La app
antigua ya tolera que `ciudad` no venga.

## Open Questions

- ¿Merece la pena enseñar `ciudad` también en el listado de preguntas del panel?
  Hoy la fila se identifica por `nombre` y la búsqueda combina
  `nombre`/`nombre_lugar` (INT-116). Queda fuera de este cambio: la ciudad no
  identifica una pregunta, y añadir columna al listado es una decisión de esa
  pantalla, no de este dato.
