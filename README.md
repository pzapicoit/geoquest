# GeoQuest

**Un juego de geografía por deducción visual.** Mira una ilustración de un lugar
del mundo, deduce dónde se tomó y clava tu respuesta en un mapa mudo. Cuanto más
cerca y más rápido, más puntos.

Trabajo de Fin de Máster — Máster en Desarrollo de Software (MoureDev).

---

## Enlaces de la entrega

| Recurso | Enlace |
| --- | --- |
| **Jugar en el navegador** | _pendiente de despliegue_ |
| **Panel de administración** | https://geoquest-seven-omega.vercel.app/ |
| **Presentación (slides)** | _pendiente_ |
| **Vídeo de presentación** | _pendiente_ |
| **Repositorio** | https://github.com/pzapicoit/geoquest |

La app web se juega **sin registro**: hay un acceso «Entrar sin cuenta como
invitado» en la pantalla de entrada. Las credenciales del panel están en
[Usuario y contraseña de prueba](#usuario-y-contraseña-de-prueba).

---

## Índice

- [Descripción general](#descripción-general)
- [Cómo se juega](#cómo-se-juega)
- [Stack tecnológico](#stack-tecnológico)
- [Arquitectura](#arquitectura)
- [Decisiones técnicas destacadas](#decisiones-técnicas-destacadas)
- [Funcionalidades principales](#funcionalidades-principales)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Instalación y ejecución](#instalación-y-ejecución)
- [Usuario y contraseña de prueba](#usuario-y-contraseña-de-prueba)
- [Calidad de código y testing](#calidad-de-código-y-testing)
- [Despliegue](#despliegue)
- [Estado actual y limitaciones](#estado-actual-y-limitaciones)

---

## Descripción general

GeoQuest es un juego móvil de geografía construido alrededor de una única
mecánica: **reconocer un lugar y situarlo en el mundo sin ninguna ayuda de
topónimos**.

El jugador avanza por un **camino** de paradas temáticas (Monumentos, Banderas,
Películas, Personas de la Historia, Museos, Circuitos F1, Olimpiadas). Cada
parada plantea una tanda de desafíos: una ilustración y una pregunta. El jugador
coloca un pin en un mapa mundial y el servidor calcula la distancia real al
objetivo, la convierte en puntos, añade un bonus por rapidez y revela la
respuesta con una animación sobre el mapa.

Las estrellas ganadas en cada parada desbloquean las siguientes. Hay comodines
para las preguntas difíciles y una clasificación entre jugadores.

El contenido no está escrito a mano en el código: se gestiona desde un **panel
de administración web**, que además puede **generar preguntas nuevas con IA**
—propone lugares reales de una temática, deja revisarlos uno a uno e ilustra
cada uno con un modelo de imagen—.

**Cifras del proyecto**

| | |
| --- | --- |
| Temáticas · desafíos · paradas | 7 · 143 · 8 |
| Código de aplicación | ~14.700 líneas Dart · ~12.600 líneas TypeScript |
| Base de datos | 47 migraciones versionadas · 15 tablas · 4 vistas · 36 funciones |
| Tests | 761 en 60 ficheros, todos en verde · 92,9 % y 90,0 % de cobertura |
| Especificaciones | 45 specs vivas · 63 cambios completados |
| Commits | 222 |

---

## Cómo se juega

1. **Entras eligiendo un apodo.** Puedes ponerle contraseña —y entonces tu
   perfil te sigue a cualquier móvil— o entrar como invitado, con el progreso
   guardado solo en ese dispositivo. En ningún caso hace falta un email.
2. **Eliges una parada** del camino. Solo la primera está abierta; el resto se
   desbloquean con las estrellas que vas acumulando.
3. **Lees la pista.** Una ilustración y una pregunta («¿Dónde se tomó esta
   imagen?»). La cuenta atrás arranca en ese momento.
4. **Colocas el pin** en el mapa mundial. Un mapa **sin nombres de países ni
   ciudades**: solo la silueta de las costas. Puedes acercarte con doble toque o
   con los controles de zoom.
5. **Confirmas.** El servidor calcula la distancia real en kilómetros, la
   traduce a puntos, suma el bonus por rapidez y revela dónde estaba de verdad
   trazando el arco de gran círculo entre tu pin y el objetivo.
6. **Cierras la parada** y recibes de 0 a 3 estrellas según el porcentaje del
   puntaje máximo que hayas alcanzado.

Si una pregunta se resiste, hay cuatro **comodines**: parar el cronómetro,
revelar el país, o dibujar un círculo de acierto de 500 km o de 150 km alrededor
de la respuesta. Como mucho uno por partida.

---

## Stack tecnológico

| Pieza | Tecnología |
| --- | --- |
| **App de jugador** | Flutter 3.47 / Dart 3.13 — iOS, Android y Web |
| **Panel de administración** | React 19 · Vite · TypeScript · Tailwind CSS 4 |
| **Base de datos** | PostgreSQL 17.6 (Supabase, `eu-west-1`) |
| **Autenticación** | Supabase Auth — apodo + contraseña sin email (jugador), sesión anónima (invitado), email + contraseña (admin) |
| **Almacenamiento** | Supabase Storage (ilustraciones de los desafíos) |
| **Lógica de servidor** | Funciones y vistas de PostgreSQL (PL/pgSQL) |
| **Edge Functions** | Deno (Supabase Functions) — custodia de la clave de OpenAI |
| **IA generativa** | OpenAI `gpt-4.1` (texto) · `gpt-image-1` (ilustraciones) |
| **Publicidad** | Google AdMob (vídeo recompensado) |
| **Mapa** | Propio: `CustomPainter` + Mercator escrito a mano sobre Natural Earth 50m |
| **Tests** | `flutter_test` · Vitest + React Testing Library |
| **Calidad** | `flutter analyze` · `dart format` · ESLint · Prettier · `tsc` · `deno lint` |
| **Despliegue** | Vercel (panel y web) · Supabase (base y funciones) |

**Dependencias destacadas de la app:** `supabase_flutter`, `google_fonts`,
`video_player`, `google_mobile_ads`, `shared_preferences`.

**Sin dependencias de mapas.** No hay Google Maps, ni Mapbox, ni teselas. Ver
[Decisiones técnicas destacadas](#decisiones-técnicas-destacadas).

---

## Arquitectura

Tres piezas y un único backend:

```
app/ (Flutter)  ─┐
                 ├─→  Supabase  ·  PostgreSQL 17.6 · Auth · Storage · PostgREST
panel/ (React)  ─┘
                        │
                        └─→  Edge Functions (Deno)  ─→  OpenAI
```

**No hay backend custom.** La app y el panel consumen el mismo proyecto de
Supabase directamente, vía REST y RPC. Toda la lógica de negocio que no puede
vivir en el cliente vive como función o vista de PostgreSQL, no como servicio
aparte.

Las **Edge Functions** existen por una sola razón: custodiar la clave de OpenAI.
El bundle del panel es público, así que no puede llevar la clave dentro; la
llamada se hace desde una función que la lee de su entorno. No son capa de
acceso a datos del juego.

Consecuencia directa: **la frontera de seguridad es Row Level Security**, no una
capa de API intermedia. Cualquier dato que un cliente no deba ver está protegido
por política, porque el cliente habla con la base sin intermediarios.

### Reparto de claves

| Clave | Quién la usa | Se salta RLS |
| --- | --- | --- |
| `sb_publishable_…` | app, panel | No |
| `sb_secret_…` | scripts de `backend/` | Sí, por completo |

La clave secreta no entra en ningún artefacto distribuible. El panel, pese a ser
administración, usa la publicable: sus privilegios salen de políticas RLS sobre
el rol del usuario autenticado (`profiles.role = 'admin'`).

### Modelo de datos

15 tablas. Las centrales:

| Tabla | Papel |
| --- | --- |
| `tematicas` | Categorías de contenido (Monumentos, Banderas…) y su estilo de ilustración |
| `desafios` | El banco de preguntas: pista, coordenada real, ciudad, país, dificultad |
| `camino` | La secuencia global de paradas: temática + dificultad + overrides |
| `dificultad_defaults` | Valores por defecto de cada nivel de dificultad |
| `intentos_nivel` · `intento_desafios` | Una partida y la selección de preguntas que le tocó |
| `respuestas_desafio` | Cada respuesta, su distancia y su puntaje |
| `progreso_usuario_nivel` | Estrellas y mejor puntaje por parada |
| `comodines_inventario` | Comodines que tiene cada jugador |
| `profiles` | Alias, rol y contadores del jugador |

Cinco enums acotan los catálogos cerrados: `dificultad`, `rol_usuario`,
`tipo_desafio`, `tipo_comodin`, `tipo_anuncio_pendiente`.

---

## Decisiones técnicas destacadas

### El mapa no usa ningún SDK de mapas

`app/lib/mapa/` dibuja el mundo con un `CustomPainter` sobre geometría de Natural
Earth 50m empaquetada como asset (`world_50m.bin`, 785 KB), proyectada con un
**Mercator escrito a mano**.

La razón de fondo no es el coste, es el juego: el mapa **no lleva ningún
topónimo**, y adivinar consiste en reconocer la forma de la costa. Cualquier
proveedor de teselas trae etiquetas —o, sin ellas, un estilo que no encaja con
el arte—. Dibujarlo nosotros es a la vez lo más barato y lo único que respeta la
mecánica: sin API key, sin facturación, sin atribución y sin red durante la
partida.

Efecto secundario que resultó decisivo: al ser Dart puro, **el mapa cruza a web
sin tocar una línea**.

El generador del asset (`app/tool/build_world_asset.dart`) corrige dos rasgos
del dataset: la Antártida viene como un polígono cuyo anillo exterior es la
arista del polo, y seis segmentos cruzan el antimeridiano. Las invariantes
resultantes están fijadas por tests sobre el binario versionado.

La aritmética de cámara (proyección, límites de zoom, recorte, pin) vive en
`MapaMundiController`, fuera del widget, y se prueba con tests unitarios puros
en vez de simulando gestos.

### El reloj de la partida es del servidor; el de la pantalla, cosmético

Los segundos transcurridos y el bonus por rapidez los calcula el servidor entre
el instante en que se marcó el desafío como mostrado y la respuesta. La cuenta
atrás que ve el jugador **no puntúa nada**, y por eso puede ser puramente de
presentación — y por eso no se puede hacer trampa cambiando la hora del
dispositivo.

Esa cuenta atrás cuelga de un *instante de fin* fijado una vez, no de acumular
avisos de un segundo: la barra avanza continua, no hay deriva, y volver de
segundo plano deja el tiempo cuadrado con el reloj real.

### La ciudad del objetivo no viaja hasta que se responde

Las vistas que alimentan la partida (`desafios_para_jugar`,
`iniciar_intento_parada`) **no exponen** la ciudad ni el país del objetivo: antes
de responder, la ciudad *es* la respuesta. Solo `responder_desafio` las devuelve.
Es una regla fijada como escenario de especificación, no como disciplina
implícita.

### Un jugador se identifica sin dar nunca un email

El jugador entra con **apodo y contraseña**. No hay email en ninguna parte del
producto: ni se pide, ni se envía, ni se verifica, ni se recupera.

Supabase Auth necesita un identificador para poder usar contraseña, así que se
deriva del apodo en el cliente, de forma determinista:

```
sha256(apodo recortado y en minúsculas) en hexadecimal + "@geoquest.invalid"
```

El dominio `.invalid` está reservado por la RFC 2606 y no puede enrutar correo,
así que ese buzón no existe ni puede existir. El hash hace la identidad
insensible a mayúsculas y a espacios sobrantes, de modo que quien se registró
como «Pablo» entra escribiendo «pablo».

Tres consecuencias que el diseño asume de forma explícita:

- **La confirmación de email tiene que seguir desactivada.** Si se activa, cada
  alta queda pendiente de un correo que nunca podrá llegar, y el jugador no
  puede entrar. Se comprueba sin credenciales contra `/auth/v1/settings`.
- **El apodo de un jugador con contraseña es inmutable**, y lo impide un trigger
  sobre `profiles`. Si la identidad deriva del apodo, renombrarlo dejaría al
  jugador fuera de su cuenta en silencio y sin arreglo posible, porque no hay
  recuperación de contraseña.
- **«Tener contraseña» es tenerla no vacía**, no que la columna exista. GoTrue
  rellena `encrypted_password` también en las altas anónimas, así que el
  criterio correcto es `coalesce(encrypted_password, '') <> ''`. Costó una
  migración correctiva descubrirlo.

Un invitado puede ponerse contraseña más tarde **sin perder su progreso**, y una
consulta `estado_apodo` dice si un apodo está libre, ocupado por alguien con
contraseña, u ocupado por un invitado — devolviendo solo ese estado, nunca la
identidad ni el identificador del jugador.

### El comodín de radio no centra el círculo en la respuesta

Los comodines de radio dibujan un círculo que acota dónde está el objetivo. La
primera versión lo centraba en la respuesta, y eso convertía el comodín en la
solución: bastaba pinchar el centro para acertar con distancia casi cero.

Ahora el servidor **desplaza el centro al azar** y garantiza que el objetivo
quede entre el **35 % y el 90 % del radio** de distancia: dentro del círculo
siempre, pero nunca en el centro. El rumbo se sortea uniformemente y la
distancia se reparte uniforme por área, para que ninguna dirección ni ninguna
franja del círculo sea más probable. Cada consumo sortea un desplazamiento
nuevo, así que gastar dos comodines sobre el mismo desafío da dos círculos
distintos.

La geometría vive en su propia función (`desplazar_centro_radio`), separada de
`usar_comodin` y deliberadamente **no expuesta como RPC pública**: al no leer ni
escribir ninguna tabla es testeable directamente contra el remoto, mientras que
`usar_comodin` descuenta inventario y no lo es.

### Generación de contenido con IA, con revisión humana obligatoria

El panel puede proponer preguntas nuevas para una temática, pero el wizard es
deliberadamente de **tres pasos con parada en el medio**: propone lugares →
el administrador los revisa uno a uno → solo entonces se ilustran y se guardan.

El motivo es económico y de calidad: ilustrar cuesta ~0,04 USD y ~24 s por
candidato, así que el momento de cazar una ciudad equivocada es *antes* de
gastarla. La deduplicación contra el banco existente (por nombre normalizado y
cercanía de coordenadas) se hace en el paso previo.

El modelo de texto se eligió **por velocidad, no por potencia**: `gpt-4.1`
devuelve tres lugares correctos en ~4 s, mientras que un modelo de razonamiento
agotó el límite de 90 s sin responder. Aquí no se le pide razonar, se le pide
recordar lugares reales.

### Desarrollo dirigido por especificación

El repositorio no solo contiene el código: contiene **45 especificaciones vivas
y 63 cambios completados** en `openspec/`. Cada funcionalidad nació de una
propuesta escrita y aprobada antes de implementarse, pasó por revisión
adversarial, tests y gates de calidad, y quedó archivada con su justificación de
diseño.

Es la parte del proyecto que más ha influido en el resultado: las decisiones
difíciles están escritas y razonadas en `openspec/changes/archive/`, no
reconstruidas a posteriori.

### Todo cambio de esquema va por migración versionada

Nunca a mano por el editor SQL. `supabase db reset --linked` reconstruye la base
solo desde las migraciones del repositorio, así que cualquier cambio manual se
perdería sin avisar. El repositorio es la fuente de verdad del esquema, y los
backfills de datos también son migraciones.

---

## Funcionalidades principales

### App de jugador (Flutter)

- **Entrada con apodo y contraseña, sin email**: crear perfil, entrar desde otro
  móvil, o jugar como invitado en un toque. Un invitado puede ponerse contraseña
  después sin perder el progreso. La pantalla avisa de que no hay recuperación de
  contraseña, porque no la hay.
- **El dispositivo recuerda los apodos** que han entrado en él, con un tope:
  elegir uno rellena el acceso —no lo completa, la contraseña sigue haciendo
  falta— y se puede olvidar de la lista.
- **Pantalla de bienvenida** al jugador reconocido, con resumen de progreso real,
  continuar partida y cambiar de jugador.
- **Camino de paradas** como pantalla principal, con arte por temática, estado
  de bloqueo, estrellas obtenidas y desbloqueo por estrellas acumuladas.
- **Puntuación por camino**: los puntos del mejor intento de cada parada, y el
  acumulado del jugador en el riel de progreso.
- **Partida**: tanda de desafíos con cuenta atrás por pregunta,
  auto-confirmación al agotarse el tiempo, y aviso visual de tiempo crítico
  (marco rojo periférico) cuando queda menos de un quinto del tiempo o menos de
  5 segundos.
- **Mapa mundial propio**: pan, zoom con controles y con doble toque, pin
  arrastrable con lectura de coordenadas.
- **Revelado animado**: arco de gran círculo entre el pin y el objetivo real,
  distancia en kilómetros, puntos, desglose del bonus por rapidez y rótulo de la
  ciudad.
- **Comodines**: parar el cronómetro, revelar el país, y círculo de acierto de
  500 km o 150 km, con el centro desplazado al azar para que acote la zona sin
  regalar el punto, y la cámara animándose para encuadrarlo. Máximo uno por
  partida.
- **Resumen de parada** con estrellas conseguidas y puntaje.
- **Clasificación** con tres pestañas: global, por camino y por temática.
- **Vídeo publicitario** (AdMob): recompensado para conseguir comodines bajo
  demanda, e intersticial recompensado como gating de partidas, con tope diario.
- **Precarga de imágenes** del intento en segundo plano, en orden de juego, para
  que llegar a cada desafío sea un acierto de caché y no una espera de red con
  la cuenta atrás corriendo.

### Panel de administración (React)

- **Login** con email y contraseña, y acceso restringido a `role = 'admin'`.
- **Dashboard** con métricas, accesos rápidos, actividad reciente y alertas de
  contenido incompleto.
- **Temáticas**: listado con reordenación y edición inline, formulario con el
  objetivo global y el estilo de ilustración que aplicará la IA.
- **Preguntas**: listado con búsqueda combinada, edición inline, formulario
  completo (pista, coordenada real, ciudad, país, dificultad) y vista previa de
  la coordenada sobre un mapa.
- **Generar con IA**: wizard de tres pasos —proponer lugares, revisar candidato
  a candidato con deduplicación contra el banco, ilustrar y guardar el lote—.
- **Camino**: gestión de la secuencia global de paradas (temática + dificultad +
  overrides por parada) con reordenación.
- **Dificultades**: valores por defecto de cada nivel (preguntas por partida,
  segundos por desafío).
- **Jugadores**: listado con búsqueda, reseteo de progreso y eliminación completa
  de un jugador (con borrado en cascada de su historial y su usuario de Auth).

### Backend (PostgreSQL + Supabase)

- **Esquema del juego** con RLS en todas las tablas y `is_admin()` como pivote de
  las políticas de escritura.
- **Cálculo de distancia y puntaje** en el servidor (`calcular_distancia_km`,
  `calcular_puntaje`), con bonus por rapidez medido server-side.
- **Ciclo de partida**: `iniciar_intento_parada` sortea las preguntas del pool de
  esa temática y dificultad, `marcar_desafio_mostrado` arranca el reloj,
  `responder_desafio` puntúa y revela, `cerrar_intento_parada` reparte estrellas
  sobre la selección real del intento.
- **Vistas seguras**: `desafios_para_jugar` sirve el contenido del desafío sin
  exponer su ubicación real; `camino_jugador` devuelve el camino con el progreso
  del jugador autenticado.
- **Clasificaciones** global, por camino y por temática, sobre el mejor intento
  de cada parada, con top N acotado, empates que comparten posición y la fila de
  quien llama siempre incluida.
- **Identidad del jugador**: `estado_apodo` informa si un apodo está libre,
  ocupado con contraseña u ocupado por un invitado, sin revelar identidad; un
  trigger impide renombrar a un jugador con credenciales, porque su identidad
  deriva del apodo.
- **Comodines**: inventario sembrado al crear el perfil, consumo mediante
  funciones `security definer` (no hay ninguna política de escritura directa) y
  concesión por anuncio con tope diario. La geometría del círculo de radio
  (`desplazar_centro_radio`) está aparte y no es RPC pública.
- **Publicidad**: `anuncio_debido` decide qué anuncio toca antes de una partida y
  `iniciar_intento_parada` recalcula la misma lógica en su propia transacción, sin
  confiar en que la app avise.
- **Métricas y alertas** para el panel, y RPCs de reordenación.
- **Auditoría** de reseteos de progreso y eliminaciones de jugador.

---

## Estructura del proyecto

```
GeoQuest/
├── app/                        Flutter — juego del jugador (iOS · Android · Web)
│   ├── lib/
│   │   ├── config/             AppConfig: configuración inyectada por --dart-define
│   │   ├── mapa/               Mapa propio: Mercator, geometría, pintor, gran círculo
│   │   ├── screens/            Splash, entrada, camino, partida, comodines, resumen, clasificación
│   │   └── services/           Gateways contra Supabase (uno por caso de uso)
│   ├── test/                   33 ficheros de test
│   ├── tool/                   build_world_asset.dart — genera el asset del mundo
│   ├── assets/world/           world_50m.bin (785 KB, Natural Earth 50m)
│   └── dart_define.example.json
│
├── panel/                      React 19 + Vite + TypeScript — administración
│   └── src/
│       ├── pages/              Login, Home, Temáticas, Preguntas, Generar IA, Camino, Dificultades, Jugadores
│       ├── components/         Layout, RequireAuth, vista previa de mapa
│       └── lib/                Lógica pura con tests (dedup, lote IA, formularios, métricas)
│
├── backend/                    Supabase — esquema, RLS, RPCs, Edge Functions
│   └── supabase/
│       ├── migrations/         47 migraciones versionadas
│       ├── functions/          proponer-lugares · generar-imagen-lugar (Deno)
│       ├── tests/              tests SQL de la lógica de Postgres
│       └── seed.sql            el banco de contenido (163 filas)
│
├── openspec/                   Desarrollo dirigido por especificación
│   ├── specs/                  45 especificaciones vivas
│   └── changes/archive/        63 cambios completados con su diseño y justificación
│
└── Recursos/                   Arte y mocks de diseño
```

Cada módulo tiene su propio README con el detalle de su flujo de trabajo:
[`app/README.md`](app/README.md), [`panel/README.md`](panel/README.md),
[`backend/README.md`](backend/README.md).

---

## Instalación y ejecución

### Requisitos

| Herramienta | Versión | Para qué |
| --- | --- | --- |
| Flutter / Dart | 3.47 / 3.13 | `app/` |
| Node.js | 20+ | `panel/` |
| Supabase CLI | reciente | `backend/` |
| Xcode | 26+ | compilar para iOS (opcional) |
| Android SDK | — | compilar para Android (opcional) |

No hace falta Docker: el flujo de base de datos es *remote-first*.

### 1. Clonar

```bash
git clone https://github.com/pzapicoit/geoquest.git
cd geoquest
```

### 2. Backend (Supabase)

Todos los comandos se lanzan **desde `backend/`**, porque el CLI está
inicializado ahí y no en la raíz del monorepo.

```bash
cd backend

supabase login
supabase link --project-ref <TU_PROJECT_REF>

cp .env.example .env.local
supabase projects api-keys --project-ref <TU_PROJECT_REF> --reveal
# …y pega los valores en .env.local

supabase db push          # aplica las 47 migraciones

# el contenido del juego (temáticas, desafíos, camino, dificultades)
supabase db query --linked -f supabase/seed.sql
```

Sin ese último paso el esquema queda montado pero **el juego no tiene nada que
jugar**: el contenido es obra de autor y vive en `seed.sql`, no en las
migraciones. El fichero es idempotente (`on conflict do update`), así que puede
aplicarse sobre una base ya poblada sin duplicar ni borrar nada. `supabase db
reset` lo ejecuta solo, al final.

Las Edge Functions y sus secretos:

```bash
supabase functions deploy proponer-lugares generar-imagen-lugar
supabase secrets set geo_open_api=sk-... --project-ref <TU_PROJECT_REF>
```

Detalle completo (modelos, variables opcionales, problemas frecuentes) en
[`backend/README.md`](backend/README.md).

### 3. App de jugador

```bash
cd app
flutter pub get

cp dart_define.example.json dart_define.json   # ya trae valores funcionales

# móvil
flutter run --dart-define-from-file=dart_define.json

# navegador
flutter run -d chrome --dart-define-from-file=dart_define.json
```

`dart_define.example.json` **ya trae la URL y la clave publicable del proyecto
de demostración**, así que copiarlo basta para arrancar. Esa clave está pensada
para viajar dentro de clientes —ya va en cualquier `.ipa` y en el bundle del
panel desplegado— y no se salta RLS, que es lo que protege los datos. La clave
secreta no está aquí ni en ningún fichero versionado.

`dart_define.json` sigue en `.gitignore` para que un valor propio no acabe
commiteado por descuido. Si falta una variable, la app aborta al arrancar
nombrando la que falta, en lugar de quedarse apuntando a un proyecto
inexistente.

Build de producción para web:

```bash
flutter build web --release --dart-define-from-file=dart_define.json
```

#### Instalar en iOS

El proyecto **no lleva la identidad de firma dentro de `Runner.xcodeproj`**: la
lee de dos variables (`GEOQUEST_BUNDLE_ID` y `GEOQUEST_DEVELOPMENT_TEAM`)
definidas en `ios/Flutter/Debug.xcconfig` y `Release.xcconfig`, que terminan con
un `#include? "Local.xcconfig"` opcional.

El bundle versionado es `es.pizpiretas.geoquest`. **El equipo de firma no se
versiona**: cada quien instala con el suyo.

Compilación para dispositivo, sin firmar (verifica que el proyecto está sano sin
necesidad de cuenta de Apple):

```bash
flutter build ios --no-codesign
```

Para instalar en un **iPhone real** hace falta un equipo de desarrollo, y el
bundle de arriba ya está registrado a uno concreto, así que Xcode se negará a
registrarlo de nuevo. Ambas cosas se sobrescriben sin tocar el proyecto, creando
`ios/Flutter/Local.xcconfig` —está en `.gitignore`—:

```
GEOQUEST_DEVELOPMENT_TEAM = TUEQUIPO
GEOQUEST_BUNDLE_ID = es.tudominio.geoquest
```

Un Apple ID gratuito (*Personal Team*) basta, pero su perfil de
aprovisionamiento caduca a los 7 días y hay que reinstalar; con una cuenta de
pago, no.

> ⚠️ **El simulador de iOS no compila ahora mismo.** `flutter build ios
> --simulator` y `flutter run` sobre un simulador fallan con «No Xcode build
> settings have been found»: `xcodebuild` no resuelve el destino
> `generic/platform=iOS Simulator` aunque `-showdestinations` sí lo liste. El
> build para dispositivo y el de web no están afectados. Ver
> [Estado actual y limitaciones](#estado-actual-y-limitaciones).

El App ID de AdMob viaja por el mismo mecanismo de xcconfig
(`GEOQUEST_ADMOB_APP_ID_IOS`), y no por `--dart-define`, porque `Info.plist` lo
necesita antes de que exista motor Dart.

Las dependencias nativas se resuelven con **Swift Package Manager**. El proyecto
no usa CocoaPods.

### 4. Panel de administración

```bash
cd panel
npm install

cp .env.example .env.local   # ya trae valores funcionales

npm run dev
```

---

## Usuario y contraseña de prueba

### App de jugador — no necesitas credenciales

La app tiene login, pero **no hace falta ninguna cuenta para jugar**, y crear una
no requiere email ni verificación:

| Cómo entrar | Qué hace falta |
| --- | --- |
| **Como invitado** | Nada. Hay un acceso «Entrar sin cuenta como invitado» en la pantalla de entrada |
| **Con perfil propio** | Un apodo libre y una contraseña que te inventes en ese momento |

No hay correo de confirmación, ni enlace que abrir, ni espera: el identificador
que necesita el proveedor de autenticación se deriva del apodo sobre un dominio
que no puede recibir correo. Detalle en
[Un jugador se identifica sin dar nunca un email](#un-jugador-se-identifica-sin-dar-nunca-un-email).

> Como no hay email, tampoco hay recuperación de contraseña, y la propia pantalla
> lo advierte antes de que la elijas. Es una consecuencia asumida del diseño, no
> un hueco pendiente.

### Panel de administración — sí necesita cuenta

Requiere una cuenta con `profiles.role = 'admin'`:

| | |
| --- | --- |
| URL | https://geoquest-seven-omega.vercel.app/ |
| Usuario | `master@geoquest.es` |
| Contraseña | `SuperMaster1981` |

> El panel es la única parte del proyecto que usa email como identificador, y lo
> hace porque sus cuentas las crea a mano quien administra, no un flujo de
> registro.
>
> Un usuario creado por la vía normal nace con `role = 'jugador'`. Para
> convertirlo en administrador hay que promoverlo desde el editor SQL del
> dashboard de Supabase:
>
> ```sql
> update profiles set role = 'admin' where id = '<uuid del usuario>';
> ```
>
> El primer administrador se crea así por diseño: no hay ninguna política RLS
> que permita a un usuario asignarse el rol a sí mismo.

---

## Calidad de código y testing

**761 tests, todos en verde**, con cobertura medida:

| Módulo | Tests | Cobertura |
| --- | --- | --- |
| `app/` (Flutter) | 474 en 33 ficheros | 92,9 % de líneas (4.649/5.002) |
| `panel/` (Vitest) | 287 en 23 ficheros | 90,0 % de sentencias (1.284/1.426) |
| `backend/` (SQL) | 4 scripts contra el proyecto remoto | — |

### Estrategia de testing

No es cobertura por cobertura: cada pieza se prueba por la vía que la hace
falsable, y varias decisiones de diseño existen precisamente *para* poder
probarla.

**El reloj se inyecta, no se consulta.** `NivelJuegoScreen` recibe `ahora`
(`DateTime Function()?`) igual que recibe sus gateways. No es un lujo:
`flutter_test` expone un reloj falso en su binding pero no instala un `withClock`
de `package:clock`, así que un *deadline* que llamara al reloj global sería
imposible de probar con `tester.pump`.

**La aritmética del mapa vive fuera del widget.** Proyección, límites de zoom,
recorte de desplazamiento y colocación del pin están en `MapaMundiController`, no
en el `State`. Eso permite probarlas con **tests unitarios puros** en lugar de
simulando gestos, que es lento y frágil.

**Los tests del asset del mundo fijan invariantes, no valores esperados.** Sobre
el binario versionado se comprueba que ningún anillo esté colapsado en una línea,
que ningún segmento cruce el mapa de lado a lado, que el mundo llegue relleno
hasta el canto inferior, que ningún anillo repita un punto y que ningún país
pierda territorio al regenerar el asset. Escritos así siguen valiendo si se cambia
de dataset; escritos como valores esperados habría que reescribirlos enteros.

**Un doble por gateway, ninguna red en los tests.** Cada servicio contra Supabase
es una interfaz abstracta con su falso en `app/test/fakes/`
(`fake_camino_gateway`, `fake_nivel_juego_gateway`, `fake_comodines_gateway`,
`fake_anuncios_gateway`…). Ningún test sale a la red ni necesita una base de
datos.

**La lógica falible se mueve a donde se puede probar.** Las Edge Functions no
llevan tests propios porque probarlas de verdad exige desplegarlas; por eso lo
que se puede equivocar en silencio —deduplicación de lugares, contabilidad del
lote, traducción de códigos de error— no vive en Deno sino en `panel/src/lib/`,
cubierto con Vitest.

**La lógica de Postgres se prueba en Postgres.** El puntaje, el bonus por
rapidez, las clasificaciones y la geometría del círculo de radio tienen tests
SQL propios en `backend/supabase/tests/`. Son scripts autónomos, sin pgTAP: el
proyecto no lo instala, y un `do $$ ... $$` con asserts cubre lo que hace falta.
Los que escriben en tablas se envuelven en `BEGIN`/`ROLLBACK`, porque corren
contra el proyecto remoto; los que solo calculan sobre sus argumentos —como
`desplazar_centro_radio`— no lo necesitan, y esa testabilidad es justo la razón
de haber separado la geometría de `usar_comodin`.

**Contrapartida asumida:** la pantalla de juego programa fotogramas mientras
corre la cuenta atrás, así que sus tests no pueden usar `pumpAndSettle` y tienen
que avanzar el tiempo a mano.

### Proceso de calidad

Ninguna funcionalidad se implementó sin una especificación aprobada antes. Cada
cambio recorrió la misma cadena, y los 63 completados están archivados en
`openspec/changes/archive/` con su propuesta, su diseño y sus tareas:

```
propuesta → aprobación → implementación → verificación contra la especificación
  → revisión adversarial → tests + cobertura + linters → validación manual
  → archivado
```

La **revisión adversarial** es un paso explícito, no una relectura: una pasada
escéptica que busca huecos, casos límite y desviaciones respecto a lo que la
especificación decía, antes de dar el cambio por bueno. Las tareas de
infraestructura sin código de aplicación (crear el proyecto, documentar,
configurar) se marcan exentas de estos gates, con su razón anotada.

Las herramientas por módulo:

| Módulo | Tests | Análisis estático | Formato |
| --- | --- | --- | --- |
| `app/` | `flutter test` | `flutter analyze` | `dart format` |
| `panel/` | Vitest + React Testing Library | ESLint · `tsc --noEmit` | Prettier |
| `backend/` | scripts SQL + `supabase db lint --linked` | `deno check` · `deno lint` | — |

### Comandos

#### App

```bash
cd app
flutter test                  # tests
flutter test --coverage       # cobertura
flutter analyze               # análisis estático
dart format --set-exit-if-changed .
```

#### Panel

```bash
cd panel
npm test                      # Vitest
npm run test:coverage         # cobertura (v8)
npm run typecheck             # tsc --noEmit
npm run lint                  # ESLint
npm run format:check          # Prettier
```

#### Backend

```bash
cd backend
supabase db lint --linked     # lint del esquema contra el remoto
supabase migration list       # divergencia local vs remoto

# tests SQL (uno por fichero; el CLI 2.111 renombró "db execute" a "db query")
supabase db query --linked -f supabase/tests/test_calcular_puntaje.sql

cd supabase/functions
deno check proponer-lugares/index.ts generar-imagen-lugar/index.ts
deno lint
```

La lógica de las Edge Functions que se puede equivocar en silencio
(deduplicación de lugares, contabilidad del lote, traducción de errores) no vive
en Deno sino en `panel/src/lib/`, donde hay tests. Las funciones se limitan a
autorizar, construir el prompt y hablar con OpenAI.

---

## Despliegue

| Pieza | Dónde | Cómo |
| --- | --- | --- |
| Panel | Vercel | Conectado al repositorio, `panel/` como *root directory*. Deploy en cada push a `main`, preview por PR |
| App web | Vercel | Build de `app/build/web` |
| Base de datos | Supabase | `supabase db push` desde `backend/` |
| Edge Functions | Supabase | `supabase functions deploy` |
| App móvil | — | No publicada en stores |

Variables de entorno del panel en Vercel: `VITE_SUPABASE_URL` y
`VITE_SUPABASE_PUBLISHABLE_KEY`. `vercel.json` añade el rewrite que evita el 404
al recargar una ruta de `react-router-dom`.

---

## Estado actual y limitaciones

Honestidad sobre lo que hay y lo que no:

- **El banco de contenido es todo de tipo imagen.** El modelo de datos soporta
  tres tipos de desafío (`imagen`, `pregunta_texto`, `video`) y la app sabe
  pintar los tres, pero los 143 desafíos actuales son ilustraciones.
- **La publicidad usa los ad units de test de Google.** El código está
  integrado y funcional; sustituir los identificadores por los de una cuenta
  AdMob real no requiere tocar código, solo configuración.
- **AdMob no soporta web.** En el navegador el SDK no está disponible: el gating
  de partidas resuelve *fail-open* (se juega igual) y la obtención de comodines
  por vídeo no está operativa.
- **En escritorio el encuadre no está pulido.** La app está diseñada en vertical
  para móvil; en una ventana ancha el layout se estira.
- **El simulador de iOS no compila.** El build para dispositivo
  (`flutter build ios --no-codesign`) y el de web funcionan, pero el destino de
  simulador falla en `xcodebuild` al resolver `generic/platform=iOS Simulator`.
  Descartados como causa: el bundle, los restos de CocoaPods,
  `SUPPORTED_PLATFORMS`, la falta de runtimes de simulador y los slices de
  simulador de las dependencias de AdMob (todos presentes y correctos). Queda
  abierto.
- **Desarrollo iOS primero.** La plataforma Android está en el proyecto y su
  identificador está alineado con el de iOS, pero no se ha compilado ni probado:
  no hay SDK de Android instalado en la máquina de desarrollo.
- **Un solo entorno.** No hay stack local ni entorno de *staging*: el proyecto
  remoto de Supabase es el único que existe.
- **Las ilustraciones siguen alojadas en el proyecto original.** El banco de
  contenido sí viaja en el repositorio (`seed.sql`), pero las imágenes son URLs
  absolutas al bucket público `challenge-media` de este proyecto de Supabase.
  Como el bucket es público, un despliegue propio funciona con imágenes desde el
  primer momento; una copia de verdad autosuficiente exigiría volver a subir los
  ficheros y reescribir las URLs.
- **No hay CI.** Los gates de calidad se ejecutan en local a través del flujo de
  trabajo del proyecto.

---

## Autor

**Pablo Zapico** — Trabajo de Fin de Máster, Máster en Desarrollo de Software
(MoureDev).
