## Context

`NivelJuegoScreen` (INT-91) arranca un intento real y muestra la pista del
primer desafío en un toast; al cerrarlo aparece `_MapaStub`, un cartel que
dice "Mapa pendiente (INT-92)". Esta propuesta sustituye ese stub por la
fase de adivinar.

Lo que ya existe y se usa tal cual:

- `iniciar_intento_nivel(p_nivel_id)` → `{intento_id, desafios[]}` (INT-95),
  ya consumido por `NivelJuegoGateway.iniciarIntento`.
- `responder_desafio(p_intento_id, p_desafio_id, p_lat_adivinada,
  p_lng_adivinada)` → fila de `respuestas_desafio` con `distancia_km` y
  `puntos` (INT-78). Nadie la llama todavía. **No** devuelve `lat_real`,
  `lng_real` ni `nombre_lugar`: RLS los esconde del jugador, así que el
  revelado de INT-93 necesitará un cambio de backend aparte.
- `ParadaCamino.nivelNombre` y `.tematicaNombre` ya viajan a la Home, así
  que el nombre del nivel se puede pasar sin consultas nuevas.

El diseño de referencia es `[App] - Pantalla de juego - Mapa.dc.html` con
`game-map.js`, ambos leídos del proyecto de Claude Design. Su mapa no usa
teselas: proyecta Natural Earth 110m con `d3.geoMercator` y lo dibuja en
SVG, sin un solo rótulo. Esa ausencia de rótulos es la mecánica del juego,
no una preferencia estética.

Restricción del proyecto: `app/` habla directo con Supabase, no hay backend
intermedio, y la lógica de negocio vive en Postgres. Esta pantalla no
calcula puntos: los pide.

## Goals / Non-Goals

**Goals:**
- Un mapa mundial a pantalla completa, sin topónimos, que funcione sin red
  y sin credenciales de ningún proveedor.
- Colocar y reposicionar un pin en coordenadas geográficas reales, con
  precisión sobrada para la fórmula de puntaje actual.
- HUD persistente sobre el mapa con progreso, nombre de nivel y puntaje
  acumulado real.
- Confirmar guarda la respuesta con `responder_desafio` y avanza al
  siguiente desafío, dejando el nivel jugable de principio a fin.
- Dejar el terreno preparado para INT-93: encuadre y proyección accesibles
  desde fuera del widget, para poder animar un `fit bounds` entre dos pines.

**Non-Goals:**
- Temporizador de cuenta atrás (INT-99): sin soporte en base de datos.
- Revelado del resultado — distancia, puntos, ubicación real, línea
  punteada (INT-93). Confirmar avanza directo al siguiente desafío.
- Cerrar el intento y calcular estrellas al terminar el nivel: hoy es
  imposible por INT-100, y su sitio natural es INT-94.
- Reanudar un intento a medias, buscador de lugares, y cualquier forma de
  mapa con etiquetas.

## Decisions

**D1 — Mapa propio dibujado con `CustomPainter`, no un paquete de mapas.**
Se descarta `google_maps_flutter` (API key, facturación, SDK nativo),
`flutter_map` con teselas OSM/CARTO (exige red en pleno juego, atribución
en pantalla, y las teselas traen rótulos — o, en las variantes sin
rótulos, un estilo claro que no encaja con el arte) y Mapbox (mismas
pegas más coste). Se dibuja el mundo con `CustomPainter` sobre geometría
empaquetada, que es lo que hace el diseño: sin red, sin claves, sin
atribución, idéntico al mockup y con control total de la cámara — que
INT-93 va a necesitar para animar el encuadre entre el pin del jugador y
la ubicación real.

**D2 — Natural Earth 50m en vez del 110m del mockup.** El mockup carga
`world-atlas` 110m, un trazado pensado para mapamundis pequeños: al
acercarse, las costas se ven poligonales y dejan de corresponderse con la
realidad. Como el juego consiste en reconocer la forma de la costa, y el
zoom llega a 14×, se usa el 50m. Las coordenadas serían idénticas con
cualquiera de los dos; lo que mejora es que lo que el jugador ve coincide
con dónde está pinchando.

**D3 — La geometría se preprocesa a un binario propio, no se lee TopoJSON
en tiempo de ejecución.** Un script de `app/tool/` descarga el TopoJSON de
`world-atlas` y emite `app/assets/world/world_50m.bin`: cabecera con
número de anillos, y luego pares `Float32` de longitud/latitud con sus
desplazamientos. Se lee con `ByteData` en unos milisegundos y sin ninguna
dependencia nueva; la alternativa (parsear TopoJSON en Dart) obligaría a
añadir un paquete o escribir el decodificador de topología a mano. El
binario se **commitea**, así que la build no depende de tener red ni de
que el CDN siga vivo.

**D4 — Proyección Mercator escrita a mano sobre coordenadas normalizadas.**
Diez líneas de matemáticas conocidas, sin paquete: el mundo se proyecta a
un cuadrado `[0,1] × [0,1]` (convención web-mercator), la latitud se acota
a ±85,051° — el límite en que Mercator se cierra en cuadrado — y el paso a
pantalla es `punto × ladoDelMundo × escala + desplazamiento`. La inversa
recupera exactamente la coordenada de partida, cosa que se prueba en un
test puro sin widgets.

**D5 — Estado de cámara y pin en un `MapaMundiController`
(`ChangeNotifier`), fuera del widget.** El widget dibuja y traduce gestos;
el controlador guarda escala, desplazamiento y pin, y expone
`pantallaACoordenadas`, `coordenadasAPantalla`, `colocarPin`, `zoomEn` y
los límites. Así la parte con reglas de verdad —recorte de zoom, recorte
de desplazamiento, normalización de longitud— se prueba con tests unitarios
puros, en vez de con simulaciones de gestos, que son frágiles. Es además
la superficie que INT-93 necesitará para encuadrar dos pines a la vez.

**D6 — Un solo `GestureDetector` con `onScale*` y `onTapUp`.** El
reconocedor de escala de Flutter cubre arrastrar con un dedo y pellizcar
con dos; el de toque solo gana si no hubo desplazamiento. Eso reproduce
sin código propio la regla del mockup ("si se movió más de 7 px no es un
toque, es un arrastre"). Los botones de zoom van en su propio `Stack` por
encima, así que sus pulsaciones no llegan al mapa.

**D7 — El pin es un widget en el `Stack`, no se pinta en el
`CustomPainter`.** Su halo late en bucle; pintarlo dentro del painter
obligaría a repintar el mundo entero en cada fotograma de esa animación.
Como widget posicionado a partir de `coordenadasAPantalla`, el mapa solo se
repinta cuando cambian escala o desplazamiento.

**D8 — El HUD sale del toast y pasa a ser una capa fija.** Hoy el progreso
y el puntaje viven dentro de `_ToastPista`, así que desaparecen justo
cuando el jugador está adivinando. En el diseño son una capa sobre el mapa
visible en las dos fases, con el botón de salir a la izquierda, el nombre
del nivel y la barra segmentada en el centro, y el puntaje a la derecha.
Se mueven ahí.

Con una desviación deliberada respecto al mockup: allí el fondo oscurecido
de la pista se dibuja *por encima* del HUD (`z-index` 20 contra 12), que
queda casi apagado. Aquí el HUD se pinta por encima de ese fondo, porque el
criterio dice que el progreso y el puntaje se ven en las dos fases y a
medio apagar no se leen.

**D9 — El nombre del nivel llega por parámetro desde el camino.**
`NivelJuegoScreen` recibe `nivelNombre`; `CaminoScreen` le pasa
`parada.nivelNombre ?? parada.tematicaNombre`, que ya tiene cargados. La
alternativa —consultar `niveles` al abrir la pantalla— añadiría una espera
de red para un texto decorativo.

**D10 — El pie de la pista es texto fijo por tipo.** El mockup muestra un
`clueCaption` ("¿Dónde se tomó esta imagen? Coloca tu pin lo más cerca que
puedas."), pero `desafios` no tiene ninguna columna equivalente y añadirla
sería un cambio de backend y de panel para un texto que no varía por
desafío. Se usa una frase fija por cada tipo de pista.

**D11 — El puntaje del HUD se acumula en el cliente, sumando lo que
devuelve cada `responder_desafio`.** El servidor ya calcula los puntos de
cada respuesta; volver a consultar el acumulado tras cada desafío sería una
llamada de red extra para sumar números que la pantalla acaba de recibir.
Sustituye al `0` fijo que dejó D3 de INT-91.

**D12 — Al responder el último desafío se vuelve al camino, sin cerrar el
intento.** Cerrar es lo que calcula estrellas y desbloquea, pero
`cerrar_intento_nivel` hoy revienta en cuanto el nivel tiene
`preguntas_por_partida` o algún desafío inactivo (INT-100), y arreglarlo
exige decidir dónde se persiste la selección de desafíos del intento. Se
deja el intento abierto —igual que ya ocurre al salir por la X— y el cierre
se implementa en INT-94, cuando exista la pantalla que enseña el resultado.

**D13 — Salir con la X solo hace `pop`.** No hay RPC para cancelar un
intento y no se inventa aquí. El intento queda abierto en `intentos_nivel`,
que es exactamente lo que ya pasa hoy cada vez que se entra y se sale de la
pantalla.

**D14 — Las animaciones del mockup se portan con animaciones implícitas y
las curvas del CSS original.** Entrada del toast `cubic-bezier(.2,.9,.3,1)`
en 320 ms, fundido del fondo en 220 ms, aparición del botón "Ver la pista",
latido del punto de la indicación y halo del pin en bucle. Son parte del
tacto de la pantalla, no adorno separable.

## Risks / Trade-offs

- **[Riesgo] El trazado 50m puede ser demasiado pesado para repintar en
  cada fotograma de un arrastre** (decenas de miles de puntos) → Mitigación:
  los `Path` se construyen una sola vez al cargar y solo se les aplica una
  transformación del canvas; el pin y su halo viven fuera del painter (D7);
  el mapa va dentro de un `RepaintBoundary`. Hay una tarea explícita de
  medir el arrastre en dispositivo; si no da 60 fps, el plan B es emitir
  dos niveles de detalle en el binario (uno grueso para zoom bajo) y elegir
  por escala, sin tocar nada más de la arquitectura.
- **[Riesgo] El script de preprocesado necesita red la primera vez** → El
  binario resultante se commitea, así que solo hace falta red para
  regenerarlo; la build y los tests nunca dependen del CDN.
- **[Riesgo] Simular gestos de pellizco en widget tests es frágil** →
  Mitigación: toda la aritmética de cámara vive en `MapaMundiController` y
  se prueba llamándolo directamente; el widget se prueba en lo que le toca
  (que un toque coloca pin, que "Confirmar" se habilita, que los botones de
  zoom no colocan pin).
- **[Trade-off] Mercator no representa más allá de ±85° de latitud**, así
  que no se puede marcar la Antártida. Es la misma limitación que tienen
  Google Maps y el propio mockup; si algún día hay un desafío allí, habrá
  que cambiar de proyección.
- **[Trade-off] El mundo no da la vuelta**: al llegar al Pacífico el
  desplazamiento se detiene en vez de continuar. Es lo que hace el diseño y
  simplifica el recorte; la alternativa (repetir el mundo) complica el
  dibujo y la colocación de pin sin aportar al juego.
- **[Riesgo] `respuestas_desafio` tiene `unique (intento_id, desafio_id)`**:
  si la respuesta llega a insertarse pero la app pierde la conexión antes de
  recibirla, el reintento fallará por duplicado y el jugador se quedará
  atascado en ese desafío → Mitigación: el mensaje de error deja reintentar
  y salir; se anota como pregunta abierta si conviene tratar el duplicado
  como "ya respondido" y avanzar.

## Migration Plan

No hay migración de datos ni cambios de esquema: la pantalla solo empieza a
llamar a una RPC que ya existía sin consumidores. Revertir es volver al
commit anterior; los intentos y respuestas que se hayan creado durante las
pruebas quedan como filas válidas de juego.

## Open Questions

- ¿Los textos fijos del pie de la pista (D10) son los que quieres, o
  prefieres que el panel permita escribirlos por desafío?
- ¿14× de zoom máximo es el tope adecuado? Da ~3,5 km por píxel; se puede
  subir si en pruebas se queda corto para islas pequeñas.
- Si un reintento de `responder_desafio` choca con el `unique`, ¿avanzamos
  al siguiente desafío dando la respuesta por buena, o se le pide al
  jugador salir del nivel?
