# Arquitectura — GeoQuest

## Forma del sistema

Tres piezas y un único backend:

```
app/ (Flutter)  ─┐
                 ├─→  Supabase  xhrntgsdlnwrvwehqfgl  (eu-west-1)
panel/ (web)    ─┘     Postgres 17.6 · Auth · Storage · PostgREST
```

**No hay backend custom.** La app de jugador y el panel de administración
consumen el mismo proyecto de Supabase directamente, vía REST y RPC. Toda la
lógica de negocio que no puede vivir en el cliente vive como función o vista en
Postgres, no como servicio aparte.

La única excepción son las **Edge Functions**, y su papel está deliberadamente
acotado: **custodiar credenciales de terceros**. Un panel cuyo bundle es público
no puede llevar una clave de OpenAI dentro, así que la llamada se hace desde una
función que la lee de su entorno (INT-113). No son capa de acceso a datos del
juego —eso sigue siendo REST/RPC directo con la clave publicable— ni sustituyen a
RLS: comprueban por sí mismas que el invocador es admin usando el JWT que reciben,
sin clave secreta.

Consecuencia directa: la frontera de seguridad es **Row Level Security**, no una
capa de API intermedia. Cualquier dato que un cliente no deba ver tiene que estar
protegido por política, porque el cliente habla con la base sin intermediarios.

## Reparto de claves

| Clave | Consumidores | Se salta RLS |
|---|---|---|
| `sb_publishable_…` | `app/`, `panel/` | No |
| `sb_secret_…` | scripts de `backend/` | Sí |

La clave secreta no entra en ningún artefacto distribuible. El panel, pese a ser
administración, usa la publicable: sus privilegios salen de políticas RLS sobre
el rol del usuario autenticado.

## Módulos

| Carpeta | Stack | Estado |
|---|---|---|
| `backend/` | Supabase CLI, SQL | esquema del juego (INT-74) + alta anónima y trigger de perfil (INT-75) + Storage de media de desafíos (INT-76) + RLS en todo el esquema del juego (INT-77) + cálculo de distancia/puntaje al responder un desafío (INT-78) + superación de nivel, estrellas y desbloqueos al cerrar un intento (INT-79) + RPCs de reorden y vistas/funciones de métricas y alertas para el panel (INT-87) + `actividad_reciente()` para el feed de altas/niveles superados del Home del panel (INT-81) + camino como secuencia propia de niveles y desbloqueo por estrellas acumuladas en el camino, sustituyendo el desbloqueo por temática (INT-98) + vista `camino_jugador` con el camino completo y el progreso del jugador autenticado, para la Home de la app (INT-96) + vista `desafios_para_jugar` y RPC `iniciar_intento_nivel` para leer contenido de desafío sin exponer su ubicación real y arrancar un intento con sus desafíos seleccionados (INT-95) + temporizador por desafío con medición server-authoritative del tiempo (`marcar_desafio_mostrado`) y bonus de puntuación por rapidez sobre `calcular_puntaje` (INT-99) + rediseño de contenido: `niveles`/`nivel_desafios` (curación manual) se eliminan; `desafios` pasa a tener `tematica_id` propio y una `dificultad` de catálogo cerrado (enum `dificultad`, 5 valores), con valores por defecto por dificultad en `dificultad_defaults` (preguntas por partida, segundos por desafío, puntuación mínima, umbrales de estrella); `camino` absorbe la configuración de las paradas (temática+dificultad+overrides opcionales) y sustituye a `iniciar_intento_nivel`/`cerrar_intento_nivel` por `iniciar_intento_parada`/`cerrar_intento_parada`, que sortean preguntas del pool de esa temática+dificultad en vez de una lista curada; `intentos_nivel`/`progreso_usuario_nivel` pasan a identificarse por `camino_id` (INT-106) + RPC de reseteo de progreso y de eliminación completa de un jugador (borra en cascada su historial y su usuario de Auth), y alias único entre jugadores a nivel de esquema (INT-111) + primeras Edge Functions del proyecto (`proponer-lugares`, `generar-imagen-lugar`) para la generación de preguntas con IA del panel: custodian la clave de OpenAI como secreto de función, exigen `profiles.role = 'admin'` al invocador y devuelven códigos de error propios que el panel traduce (INT-113) + `tematicas.prompt_imagen`: estilo de ilustración por temática que la generación con IA aplica a todas sus imágenes, y que gobierna solo la ilustración — qué lugares se proponen se sigue deduciendo del banco de la temática (INT-113 delta-1) + los umbrales de estrella y `estrellas_requeridas` dejan de almacenarse: `dificultad_defaults`/`camino` pierden esas columnas (quedan solo `preguntas_por_partida`/`segundos_por_desafio` configurables) y se derivan en tiempo de lectura — `puntaje_maximo_por_desafio()` (deriva el máximo de `calcular_puntaje`, sin literal `5500`), `umbrales_parada(dificultad, preguntas_por_partida)` (porcentajes fijos por dificultad, `floor`) y `estrellas_requeridas_por_orden(orden)`; `cerrar_intento_parada` calcula sobre el tamaño real de la selección persistida del intento (`intento_desafios`), no sobre la config vigente, y su respuesta gana `puntaje_maximo`; nueva vista `camino_panel` para que el listado del admin lea `estrellas_requeridas` derivada (INT-115) + `tematicas.objetivo_global` (qué se pregunta en la temática) y `desafios.nombre`/`pista` (identificador corto de la pregunta y pista opcional sin uso aún), separados del rol de `nombre_lugar` (solo la respuesta real); `desafios_para_jugar`/`iniciar_intento_parada` exponen `nombre`/`objetivo_global`; migración de datos corrige `nombre_lugar` en 24 preguntas y `lat_real`/`lng_real` en 7 cuya coordenada no correspondía al lugar real (INT-116) |
| `app/` | Flutter 3.47 + `supabase_flutter` + `google_fonts` + `video_player` | sesión anónima automática en el arranque (INT-75) + splash con branding e icono de app (INT-88) + pantalla de apodo con guardado en `profiles` (INT-89) + camino de niveles como Home (INT-90) + pantalla de juego: pista en toast (INT-91) y fase de adivinar sobre mapa mundial con pin, confirmación contra `responder_desafio` y salida con aviso (INT-92) + cuenta atrás por desafío con auto-confirmación al agotarse y desglose de bonus por rapidez en el revelado (INT-99) + arranque de intento y camino identificados por `camino_id` (parada) en vez de `nivel_id`; sin cambio de vocabulario de cara al jugador (INT-106) + splash con animaciones de entrada y fondo compartido con las pantallas de entrada (`EntryBackdrop`/`entry_motion.dart` de INT-108), en vez de la composición estática de INT-88 (INT-107) + sensación de juego de la pantalla de partida: cuenta atrás continua contra un instante de fin, marco rojo periférico en tiempo crítico y doble toque para acercar el mapa sobre un punto (INT-114) + el toast de pista muestra el `objetivo_global` de la temática de la parada junto al `nombre` del desafío actual, para los tres tipos de contenido (INT-116) |
| `panel/` | React 19 + Vite + TypeScript, Tailwind CSS | login (INT-80) + Home/dashboard con layout fijo, métricas, accesos rápidos, actividad reciente y alertas de contenido (INT-81) + pantalla "Camino" para gestionar la secuencia global de niveles (INT-98) + campo de segundos por desafío en la configuración del nivel (INT-99) + selector de temática/dificultad y edición inline en el formulario y listados de preguntas, pantalla "Dificultades" para los valores por defecto, "Camino" reescrito sobre temática+dificultad con overrides por parada, retirada de las pantallas de niveles (listado y detalle), edición inline de estado en el listado de temáticas (INT-106) + pantalla "Jugadores" con listado/búsqueda, reseteo de progreso y eliminación completa de un jugador con confirmación (INT-111), pantalla "Generar con IA" con wizard de tres pasos (propuesta de lugares → revisión candidato a candidato → ilustración estilo Pixar y guardado del lote), deduplicando contra el banco por nombre normalizado y cercanía de coordenadas (INT-113), campo de prompt de imagen en el formulario de temáticas y aviso en el paso 1 del estilo que se aplicará (INT-113 delta-1), desplegado en https://geoquest-seven-omega.vercel.app/ + formulario de temática con `objetivo_global` obligatorio; formulario de pregunta con `nombre` como primer campo obligatorio y `pista` opcional; listado de preguntas identifica cada fila por `nombre` y la búsqueda combina `nombre`/`nombre_lugar` (INT-116) |

### El mapa de juego no usa ningún SDK de mapas

`app/lib/mapa/` dibuja el mundo con un `CustomPainter` sobre geometría de
Natural Earth 50m empaquetada como asset (`assets/world/world_50m.bin`, 785 KB,
regenerable con `dart run tool/build_world_asset.dart`), proyectada con un
Mercator escrito a mano. No hay Google Maps, ni Mapbox, ni teselas: no hace
falta API key, ni facturación, ni atribución, ni red durante la partida.

La razón de fondo no es el coste, es el juego: el mapa **no lleva ningún
topónimo**, y adivinar consiste en reconocer la forma de la costa. Cualquier
proveedor de teselas trae etiquetas —o, sin ellas, un estilo que no encaja con
el arte—, así que dibujarlo nosotros es a la vez lo más barato y lo único que
respeta la mecánica.

La aritmética de cámara (proyección, límites de zoom, recorte de
desplazamiento, pin) vive en `MapaMundiController`, fuera del widget, y se
prueba con tests unitarios puros en vez de simulando gestos. Desde INT-114 el
encuadre con foco se puede pedir como valor (`camaraDeZoomEn`) además de
aplicarlo (`zoomEn`): el controlador no tiene `vsync`, así que animar hacia un
encuadre es cosa del widget, pero los topes y el recorte siguen calculándose en
un solo sitio.

**El doble toque se detecta a mano, no con un `DoubleTapGestureRecognizer`
(INT-114).** Registrar ese reconocedor en el `GestureDetector` del mapa mete al
reconocedor de toque simple en una arena donde ya no puede ganar al levantar el
dedo: colocar el pin —la acción principal de la pantalla de juego— se retrasaría
`kDoubleTapTimeout` (300 ms). Así que el pin se sigue colocando en `onTapUp`, y
es ese mismo manejador el que recuerda el toque anterior (plazo del framework,
slop propio de 40 px) y lanza el acercamiento animado cuando los dos toques
caen juntos.

Y un doble toque **solo acerca**: acercarse a mirar y responder son dos
intenciones distintas, así que al confirmarse se deshace el pin que había
colocado su primer toque y el mapa vuelve al que hubiera antes del gesto. La
primera versión heredaba ese pin, y un jugador que ya tenía su respuesta puesta
la perdía al acercarse a mirar otra zona. El precio es que en un doble toque el
pin aparece y desaparece en menos de 300 ms: se prefiere eso antes que retrasar
el toque simple hasta saber si viene un segundo.

**El generador del asset arregla dos rasgos del dataset (INT-103).** En
world-atlas la Antártida viene como un polígono cuyo anillo exterior es la
arista del polo (área cero) y cuyo supuesto agujero es la costa; tratados como
anillos sueltos, el relleno se cortaba antes del borde inferior y la arista se
trazaba como una raya. Y seis segmentos del dataset cruzan el antimeridiano,
que en la proyección salta de un borde del cuadrado al otro. `build_world_asset.dart`
fusiona los polígonos con un anillo de área cero y parte los que cruzan el
meridiano 180. Las invariantes resultantes —sin anillos degenerados, sin saltos
de más de 180°, sin puntos repetidos, relleno hasta el canto— están fijadas por
tests sobre el binario commiteado, no por valores esperados, para que sigan
valiendo si se cambia de dataset.

**Rendimiento del pintor, medido en dispositivo (INT-103).** El mundo se
repinta entero en cada fotograma de gesto: un `Path` de 99 541 puntos, más la
pasada de contorno. Perfilado en iPhone real en modo profile con el timeline de
DevTools, sobre el gesto de zoom y la animación del revelado, **no aparece jank
apreciable** (no se registraron cifras concretas). Así que la caché de una
`Picture` y el recorte a lo visible se descartan por ahora: no hay problema que
resolver. Si el asset creciera —pasar a Natural Earth 10m es la vía obvia para
más detalle de costa— esta medida deja de valer y hay que repetirla antes de
subir la resolución.

### El reloj de la partida es del servidor; el de la pantalla, cosmético

`segundos_transcurridos` y el bonus por rapidez los calcula el servidor entre
`intento_desafios.mostrado_en` y la respuesta (INT-99). La cuenta atrás que ve el
jugador no puntúa nada, y por eso puede ser puramente de presentación.

Desde INT-114 esa cuenta atrás (`CuentaAtrasDeDesafio`, en
`app/lib/screens/`) cuelga de un **instante de fin** que se fija una vez al
volverse actual el desafío, y no de acumular avisos de un segundo: un `Ticker`
solo dice "hay fotograma nuevo, recalcula". Con eso la barra avanza continua
—cambia entre segundo y segundo, la etiqueta se queda en enteros—, no hay deriva
y volver de segundo plano deja el tiempo cuadrado con el reloj real en vez de con
los fotogramas entregados. La contrapartida es que la pantalla de juego programa
fotogramas mientras corre el tiempo: los tests que la montan no pueden usar
`pumpAndSettle`.

El reloj de pared se **inyecta** en `NivelJuegoScreen` (`ahora`), como ya se
inyectan sus gateways. No es opcional: `flutter_test` expone su reloj falso en
`binding.clock` pero no instala un `withClock` de `package:clock`, así que un
deadline que llamara al reloj global no se podría probar con `tester.pump`.

La zona crítica de tiempo (rojo de la barra y marco de aviso) tiene una sola
definición, en esa misma pieza: menos de una quinta parte del desafío **o** menos
de 5 segundos. El suelo existe porque en las dificultades cortas una quinta parte
son 1-2 s y el aviso llegaría tarde para servir de algo.

## Flujo de base de datos

**Remote-first.** Las migraciones se escriben en local y se aplican al proyecto
remoto con `supabase db push`. No hay stack local con Docker.

Las políticas RLS también se pueden probar contra el remoto: se crean usuarios de
prueba por la API de Auth, se obtienen sus JWT y se lanzan peticiones como ellos.
Lo que se pierde es menor —usuarios que se acumulan en `auth.users` y setup
destructivo sobre el único entorno—, así que Docker queda **sin fecha**: se
instala si y cuando probar RLS resulte incómodo, no por calendario.

Todo cambio de esquema va por migración versionada. Nunca a mano por el SQL
editor: `supabase db reset --linked` reconstruye la base solo desde las
migraciones del repo, y se lleva por delante cualquier cambio manual.

Consecuencia de no tener segundo entorno: el proyecto remoto es el único que
existe, así que **el contenido de trabajo debe ser reproducible desde
`backend/supabase/seed.sql`**. Lo que solo viva dentro de la base se pierde en el
primer reset.

## Herramientas de calidad

Declaradas para los gates de `/execute`.

### backend/

| Gate | Herramienta |
|---|---|
| Tests | `supabase db lint --linked` sobre las migraciones (remoto, sin Docker) |
| Cobertura | no aplica — la lógica testeable de las Edge Functions vive en `panel/src/lib/` |
| Quality | `supabase db lint`, `deno check` y `deno lint` sobre `supabase/functions/`, revisión de que todo cambio de esquema va por migración |

Las Edge Functions no llevan `deno test`: se quedan en autorizar, construir el
prompt y hablar con OpenAI, así que un test suyo sería un mock de la llamada de
red. Lo que se puede equivocar en silencio (deduplicación de lugares, contabilidad
del lote, traducción de errores) vive en `panel/src/lib/` con Vitest. Probarlas de
verdad exige desplegarlas: `supabase functions serve` pide Docker, que este
proyecto no usa.

Cuando exista esquema (INT-74) conviene revisar si merece la pena pgTAP para las
políticas RLS. Las políticas son exactamente el tipo de cosa que se rompe en
silencio, así que probablemente sí.

### app/

| Gate | Herramienta |
|---|---|
| Tests | `flutter test` |
| Cobertura | `flutter test --coverage`, umbral por definir |
| Quality | `flutter analyze`, `dart format --set-exit-if-changed` |

La configuración se inyecta con `--dart-define-from-file=dart_define.json`. Ese
fichero está gitignorado; la plantilla es `dart_define.example.json`.

Herramientas de máquina: Flutter 3.47.0 / Dart 3.13.0, Xcode 26.6 y Chrome
disponibles.

**iOS primero.** El desarrollo arranca por iOS; Android queda para más adelante.
El proyecto Flutter ya incluye la plataforma `android/`, así que activarlo es
solo instalar el SDK de Android — no hay que tocar el proyecto.

### panel/

| Gate | Herramienta |
|---|---|
| Tests | Vitest + React Testing Library |
| Cobertura | `vitest run --coverage`, umbral por definir |
| Quality | ESLint, Prettier, `tsc --noEmit` |

**Stack:** React 19 + Vite + TypeScript, Tailwind CSS, desplegado en Vercel.

Decidido en INT-80 frente a Next.js y Flutter Web. No hay backend propio —
panel y app hablan directo con Supabase con la clave publicable, RLS es la
única frontera de seguridad — así que el SSR de Next.js no aporta nada aquí:
una SPA basta. El diseño de las pantallas del panel llega ya maquetado en
HTML/CSS desde Claude Design, lo que hace de React+Tailwind una traducción casi
directa; Flutter Web habría significado reimplementar ese layout como widgets
Dart sin ganar reuso real de lógica con `app/`, porque la lógica de negocio
vive en Postgres, no en el cliente.

Supabase no ofrece hosting de frontend (solo Postgres, Auth, Storage, Edge
Functions), así que el panel se despliega en Vercel: conecta directo con el
repo, deploy en cada push a `main` y preview automático por PR.

**URL:** https://geoquest-seven-omega.vercel.app/

## Exenciones

Las tareas de infraestructura sin código de aplicación (crear el proyecto,
linkar, documentar, configurar CI) se marcan `exempt` en las métricas, con razón.
No tiene sentido exigir cobertura a un `config.toml`.
