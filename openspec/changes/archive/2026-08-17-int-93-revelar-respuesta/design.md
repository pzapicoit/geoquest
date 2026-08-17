## Context

Tras INT-92 la pantalla de juego es jugable de principio a fin: pista →
mapa → confirmar → siguiente desafío. Lo que falta es justo el momento en el
que el jugador se entera de algo: hoy confirma y la pantalla salta a la
pista siguiente con unos puntos nuevos en el HUD, sin decir dónde estaba el
lugar ni cuánto se desvió.

Lo que ya existe y se usa tal cual:

- `MapaMundiController` (INT-92, D5 de su `design.md`): escala,
  desplazamiento y pin, con `coordenadasAPantalla`, `pantallaACoordenadas`,
  `zoomEn` y los recortes de zoom/desplazamiento. Se dejó pensando en esto:
  *"es además la superficie que INT-93 necesitará para encuadrar dos pines a
  la vez"*.
- `MapaMundi` + `_PintorMundo`: geometría empaquetada, `Path` construidos
  una vez y una única transformación de canvas; el pin vive fuera del
  pintor (D7 de INT-92).
- `responder_desafio(p_intento_id, p_desafio_id, p_lat_adivinada,
  p_lng_adivinada)` → fila de `respuestas_desafio` con `distancia_km` y
  `puntos` (INT-78). Es `security definer` porque lee
  `desafios.lat_real/lng_real`, que RLS esconde del jugador (INT-77), y
  **no** devuelve ni esas coordenadas ni `nombre_lugar`. Ese es el bloqueo
  que este cambio levanta.
- `respuestas_desafio` tiene `unique (intento_id, desafio_id)`: cada desafío
  de un intento se responde una vez y solo una.

El diseño de referencia es `[App] - Revelar respuesta.dc.html` con
`reveal-map.js`, leídos del proyecto de Claude Design. Su secuencia es:
aparece el pin real (620 ms de espera, 520 ms de rebote) → encuadre de los
dos pines (1400 ms) → línea punteada progresiva (1000 ms) → contador de
distancia (1000 ms) → destello y contador de puntos (900 ms). La hoja de
resultado entra desde abajo (420 ms) con los contadores a 0.

Restricción del proyecto: `app/` habla directo con Supabase y la lógica de
negocio vive en Postgres. Esta pantalla no calcula distancia ni puntos: los
pide y los enseña.

## Goals / Non-Goals

**Goals:**
- Que confirmar deje de ser un salto al vacío: ver dónde estaba el lugar,
  cuánto se desvió el pin y de dónde salen los puntos.
- Abrir la ubicación real del desafío **solo** a quien acaba de responderlo,
  sin agrietar lo que INT-77/INT-95 protegen.
- Portar la coreografía del diseño con una sola fuente de tiempo, cancelable
  y repetible, y probable en tests de widget sin simular gestos.
- Dejar la cámara del mapa manejable desde fuera (encuadrar un conjunto de
  coordenadas, adoptar un encuadre) sin romper sus límites.

**Non-Goals:**
- Pantalla de resumen del nivel y cierre del intento con estrellas (INT-94,
  hoy bloqueado por INT-100): "Ver resultados" vuelve al camino, igual que
  hoy.
- Reproducir el vídeo de la pista en la miniatura del revelado.
- Historial de respuestas de intentos anteriores, ni volver a ver el
  revelado de un desafío ya pasado.
- Tocar la curva de puntaje (INT-78) o el temporizador (INT-99).

## Decisions

**D1 — `responder_desafio` devuelve `jsonb` con la respuesta y el revelado,
en vez de una RPC de revelado aparte.** El tipo de retorno actual es la
propia fila de `respuestas_desafio`, que no se puede ampliar sin cambiar la
tabla. Alternativas descartadas: (a) una RPC nueva
`revelar_desafio(intento, desafio)` que compruebe que ya hay respuesta
registrada — dos viajes de red en el momento de más tensión de la pantalla y
una superficie más que auditar, con la misma exposición de datos; (b) una
vista de respuestas con el lugar unido — el jugador ya puede leer sus
`respuestas_desafio` por RLS, pero un `join` con `desafios` obliga a una
vista `security definer` y sigue siendo un segundo viaje. Se elige el
`jsonb`, con el precedente de `iniciar_intento_nivel` (D4 de INT-95). Coste:
al cambiar el tipo de retorno la migración hace `drop function` + `create`,
y el único llamante es la app.

**D2 — El revelado se entrega como resultado de la jugada, nunca como
consulta.** La garantía no es una comprobación nueva: es el
`unique (intento_id, desafio_id)` que ya tiene la tabla. Para conocer la
ubicación real de un desafío hay que gastar la única respuesta que ese
intento le puede dar, y quedarse con los puntos que salgan de la coordenada
enviada. Ni `desafios`, ni `desafios_para_jugar`, ni
`iniciar_intento_nivel` cambian, y `desafios` sigue sin política de
`select` para jugadores.

**D3 — `puntos_maximos` lo dice el servidor (`calcular_puntaje(0)`), no una
constante en la app.** La curva de puntaje vive en Postgres y está anotada
como *"constantes de partida sin validar con playtesting"* (INT-78):
duplicar el 5000 en Dart lo dejaría desincronizado en silencio el día que se
ajuste. Se calcula en la propia RPC, que ya tiene la función a mano.

**D4 — Una sola `AnimationController` para toda la coreografía, con los
tramos recortados por tiempo.** La duración total (≈5,4 s) se reparte en los
intervalos del diseño —pin real, encuadre, línea, contador de distancia,
destello y contador de puntos—, y cada tramo lee de ese único reloj los
milisegundos que le tocan. Alternativa descartada: cadena de `Timer` + varios
controladores, que es lo que hace el JS — obliga a cancelar cinco cosas al
salir, y en tests exige encadenar esperas reales. Con un controlador único,
repetir la animación es `forward(from: 0)`, cancelar es `dispose`, y un test
llega a cualquier instante con un `pump(Duration)`.

**D5 — El encuadre lo calcula `MapaMundiController`; la pantalla solo lo
anima.** El controlador gana `camaraPara(coordenadas, {margenes})` →
`CamaraMapa(escala, desplazamiento)` con los mismos recortes de zoom y
desplazamiento que cualquier gesto, y `aplicarCamara(camara)`. La pantalla
interpola linealmente entre la cámara actual y la calculada, con la curva
`easeInOutCubic` del diseño. Así la aritmética con reglas se prueba llamando
métodos (D5 de INT-92) y la animación no se cuela en el controlador, que no
tiene `vsync`.

Los márgenes son distintos arriba y abajo (168 / 404 px en el diseño):
abajo está la hoja de resultado y un pin oculto detrás de ella sería
exactamente el fallo que este cambio viene a arreglar. Se pasan como
`EdgeInsets` desde la pantalla, que es la que sabe cuánto ocupa su hoja, y en
proporción de la altura en vez de en píxeles fijos, para que en una pantalla
pequeña la hoja tampoco tape un pin.

Si el mapa cambia de tamaño a media animación —una rotación, que la app no
bloquea—, el encuadre de destino se recalcula y la interpolación sale desde
donde esté la cámara: llegar bien al encuadre nuevo importa más que la
suavidad del tramo que quedaba.

**D6 — La línea punteada es su propio `CustomPainter` en espacio de
pantalla, con la geometría en funciones puras.** Dos funciones en `mapa/`:
interpolación del gran círculo entre dos coordenadas (slerp sobre vectores
unitarios, como el `d3.geoInterpolate` del diseño) y troceado de una
polilínea en guiones con un patrón dado. Se prueban sin construir un
widget. No se dibuja dentro de `_PintorMundo` porque sus `Path` se
construyen una sola vez y solo se transforma el canvas: la línea cambia en
cada fotograma mientras se traza, y sus guiones no deben escalar con el
zoom (el `non-scaling-stroke` del mockup).

**D7 — El pin real reutiliza el pintor del pin del jugador,
parametrizado.** En el diseño los dos pines son el mismo dibujo con otro
color de relleno y de halo, más un rótulo encima ("Tu pin" / "Real"). Se
parametriza `_PintorPin` con los colores y se añade el rótulo. Los rótulos
aparecen **solo** en el revelado: en la fase de adivinar hay un único pin y
no hay nada de lo que distinguirlo.

**D8 — El pin real y el progreso de la línea viven en
`MapaMundiController`; el resto del revelado, en la pantalla.** Son estado
de lo que el mapa dibuja, de la misma familia que el pin del jugador, y así
la animación los mueve sin que la pantalla se reconstruya entera en cada
fotograma: el mapa se repinta por su `AnimatedBuilder` y los contadores por
los suyos. Lo que sí es de la pantalla es la fase: un objeto `_Revelado`
con la respuesta del servidor y el pin confirmado, `null` cuando no hay
revelado. Sin banderas sueltas no se puede llegar a una hoja de resultado
sin datos.

**D9 — Miniatura de la pista: la imagen si el desafío es de tipo `imagen`,
un distintivo del tipo si es `video` o `pregunta_texto`.** Sacar un
fotograma del vídeo exigiría un paquete con dependencia nativa
(`video_thumbnail`) y un fichero en disco, o mantener vivo el decodificador
del toast durante todo el revelado; y una pregunta de texto no tiene imagen
que enseñar. El icono del tipo, sobre el mismo degradado claro del diseño,
dice lo mismo que la miniatura: de qué pista venía esto.

**D10 — El HUD conserva la X durante el revelado, a diferencia del
mockup.** El diseño quita el botón de salir de esta pantalla, pero la spec
lo pide "visible en todo momento" y quitar la salida justo cuando corre una
animación de cinco segundos es peor producto. Misma desviación deliberada,
y por el mismo motivo, que D8 de INT-92.

**D11 — "Repetir animación" no vuelve a llamar al servidor.** La respuesta
está guardada en la pantalla; repetir es `forward(from: 0)` sobre el mismo
dato. Tampoco vuelve a sumar puntos: el puntaje acumulado del intento se
incorpora al avanzar, y durante el revelado lo que se ve es
`puntaje + contador`.

**D12 — La distancia se muestra en kilómetros enteros, con un decimal por
debajo de 10 km.** El diseño enseña enteros con separador de millares
español, y se respeta; pero un pin a 400 m del lugar se leería como "0 km",
que parece un fallo justo en el mejor acierto posible. Por debajo de 10 km
se muestra un decimal con coma. El contador anima el valor y el formateador
decide cómo se lee.

**D13 — El avance no es automático ni al terminar la animación.** El botón
de continuar está disponible desde el primer instante del revelado, así que
quien ya lo ha visto veinte veces se lo salta de un toque; y quien quiere
mirar el mapa se queda ahí el tiempo que quiera. Un avance automático
obligaría a elegir un tiempo bueno para todos, que no existe.

**D14 — La migración solo reemplaza `responder_desafio`.** El trigger
`respuestas_desafio_antes_de_insertar` y las funciones
`calcular_distancia_km`/`calcular_puntaje` no se tocan: el cálculo del
servidor y su garantía frente a inserts directos siguen exactamente igual.

**D15 — La línea se parte donde cruza el antimeridiano.** (Decidido al
implementar.) El mundo del mapa no se repite (trade-off de INT-92), así que un
arco que va de 179° E a 179° O salta de un borde al otro y, dibujado del
tirón, cruza la pantalla entera trazando exactamente la ruta que no es — un
pin en Japón y un lugar en California darían una línea por Eurasia y el
Atlántico. El arco se parte en los cruces y cada trozo se va por su borde,
que es como se dibuja cualquier ruta de vuelo sobre un plano.
`reveal-map.js` no lo hace: su cámara tampoco envuelve, así que arrastra el
mismo fallo latente y aquí no se copia.

**D16 — Pasar de desafío devuelve el mapa a su encuadre de partida.**
(Decidido al implementar.) Tras un revelado la cámara se queda encima de la
respuesta anterior; heredar ese encuadre en el desafío siguiente deja al
jugador mirando de cerca una región que ya no viene a cuento, y en un nivel
temático es además media pista. `reveal-map.js` reencuadra en cada `play()`
por el mismo motivo.

## Risks / Trade-offs

- **[Riesgo] Farmear el banco de preguntas repitiendo intentos**: quien
  responda a lo loco un intento entero se queda con las ubicaciones de esos
  desafíos y las clavará en el siguiente → Mitigación parcial: los niveles
  con `preguntas_por_partida` reparten al azar, y el progreso guarda el
  *mejor* puntaje, así que el coste de farmear es jugar el nivel dos veces.
  Es inherente a revelar la respuesta —lo hace cualquier juego del género— y
  no se resuelve escondiendo el dato, sino con reglas de intento (INT-99) si
  algún día molesta.
- **[Riesgo] `drop function` + `create` deja la RPC inexistente unos
  milisegundos, y una app ya desplegada rompería con el `jsonb` nuevo** →
  Mitigación: hoy no hay build publicada, solo desarrollo. En cuanto la haya,
  un cambio así tendrá que ir versionado (RPC nueva y retirada de la vieja
  cuando nadie la llame).
- **[Riesgo] La coreografía de 5,4 s se hace larga a la décima vez** →
  Mitigación: el botón de continuar está activo desde el principio (D13);
  se anota como pregunta abierta si conviene además acortar los tramos.
- **[Riesgo] Interpolar la escala linealmente entre dos encuadres puede dar
  un movimiento raro cuando el salto de zoom es grande** (es lo que hace el
  diseño) → Mitigación: si en pruebas se ve un "tirón", se interpola la
  escala de forma logarítmica sin tocar nada más; el cálculo del encuadre de
  destino no cambia.
- **[Riesgo] Tests de widget con animaciones largas y un halo en bucle**:
  `pumpAndSettle` no termina nunca → Mitigación: los tests avanzan con
  `pump(Duration)` explícitos, como ya hacen los de INT-91/92.
- **[Trade-off] El revelado no se puede volver a consultar**: si la app se
  cierra en pleno revelado, ese dato se pierde (la respuesta queda
  registrada, pero la ubicación real solo viajó en la respuesta de la RPC).
  Guardar el revelado en cliente sería un caché de algo que INT-94 va a
  tener que resolver de otra manera para el resumen del nivel.
- **[Trade-off] La línea punteada se recalcula en cada fotograma del
  encuadre** (60 puntos proyectados) → Es aritmética trivial frente al
  repintado del mundo que ya ocurre en ese mismo fotograma.

## Migration Plan

1. `supabase db push` de la migración nueva: `drop function
   responder_desafio(uuid, uuid, double precision, double precision)` y
   `create` de la versión que devuelve `jsonb`, con su `revoke`/`grant`
   (Postgres vuelve a conceder `execute` a `public` en cada función nueva).
2. Desplegar la app. El orden importa: la app nueva no funciona con la RPC
   vieja ni al revés, y por eso se hace primero el backend, que es el que
   convive con las dos formas durante el paso.
3. Sin migración de datos: `respuestas_desafio` no cambia de forma y las
   filas ya registradas siguen siendo válidas.
4. Revertir es volver al commit anterior y aplicar una migración que
   restaure la firma antigua; las respuestas registradas mientras tanto no
   se ven afectadas.

## Open Questions

- ¿Los tiempos del diseño (≈5,4 s en total) aguantan la décima repetición, o
  acortamos los tramos de encuadre y línea?
- ¿El decimal por debajo de 10 km (D12) es lo que quieres, o preferimos
  enteros a secas como el mockup?
- Para el desafío de tipo vídeo, ¿te vale el distintivo del tipo como
  miniatura (D9), o merece la pena el paquete nativo para sacar un
  fotograma?
- ¿"Ver resultados" en el último desafío debería quedar deshabilitado hasta
  que exista la pantalla de resumen (INT-94), o está bien que devuelva al
  camino como hoy?
