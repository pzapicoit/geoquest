## Context

Delta funcional de `int-114-juego-tiempo-critico-zoom` tras probarlo en el
móvil. El cambio padre está archivado y sus requisitos ya viven en
`openspec/specs/app-game-screen` y `openspec/specs/app-world-map`; este delta
los modifica.

Lo que hay hoy:

- `_MarcoDeTiempoCritico` (`nivel_juego_screen.dart`) es un `Positioned.fill`
  con `IgnorePointer` y dos `DecoratedBox` anidados: `Border.all(width: 3)` a
  la opacidad calculada, y dentro otro de 7 px al 22 % como halo. Sin radio y
  sin margen: el rectángulo llega justo a los cuatro cantos.
- `_MapaMundiState._alTocar` coloca el pin en cada toque y, si el toque es el
  segundo de una pareja cercana (40 px) dentro de `kDoubleTapTimeout`, además
  lanza el acercamiento. Era D13 del padre: dejar el pin donde el jugador
  quería mirar de cerca.

Restricción nueva que impone el hardware: Flutter **no expone el radio de las
esquinas del dispositivo**. No hay `MediaQuery` que lo diga, ni en iOS ni en
Android, así que el marco no puede copiar el radio real: tiene que caber dentro
de cualquiera.

## Goals / Non-Goals

**Goals:**

- Que el marco se vea entero en un móvil con esquinas redondeadas, sin
  depender de saber su radio.
- Que se note un poco más sin dejar de ser un borde fino.
- Que el doble toque signifique solo "acércame", y que no se lleve por delante
  la respuesta que el jugador ya había colocado.

**Non-Goals:**

- Retrasar el pin del toque simple. Sigue siendo la acción principal y sigue
  siendo instantánea.
- Tocar la cuenta atrás, el umbral de zona crítica, el factor 2× o el backend.
- Detectar el radio real del dispositivo con plugins o canales nativos.

## Decisions

### DD1 — Margen + radio generoso en vez del radio del dispositivo

El marco se mete **6 px** hacia dentro y se dibuja con **radio 56**.

La condición no es una fórmula bonita: es que todos los puntos del contorno del
marco caigan dentro del área visible, que es un rounded rect de radio
desconocido. Muestreando el contorno completo contra esa área, margen 6 y radio
56 entran en una pantalla con esquinas de **hasta 76 px de radio**; un iPhone
reciente ronda los 55.

Dos formas de calcularlo mal, las dos probadas y descartadas por el camino:

- La regla "paralela" `r ≥ R − m` es **suficiente pero no necesaria**: da 51
  como mínimo para R=55, cuando en realidad radio 44 con margen 4 ya aguantaba
  hasta 57. Usarla habría hecho el marco más redondo de lo necesario.
- Medir solo el punto de la diagonal falla al revés: cuando el radio del marco
  es mayor que el del dispositivo, el arco del marco se sale del cuadrante de la
  esquina, donde la restricción ya no es el arco sino el propio canto de la
  pantalla, y el cálculo da por cortado algo que entra.

Los 6/56 no son el mínimo que funciona: son el mínimo con holgura. El margen de
un radio 44 sobre los 55 de un iPhone era de 2 px, y esto es un borde decorativo
en un parque de dispositivos que no controlamos.

Alternativa descartada: leer el radio con un plugin nativo. Una dependencia y un
canal de plataforma para colocar un borde decorativo, cuando dos constantes
resuelven el caso en todos los tamaños.

### DD2 — 4 px de trazo, 8 px de halo, y los dos con el mismo radio

3 → 4 px el borde y 7 → 8 px el halo interior. Es el "un pelín" que se pidió:
un 33 % más de trazo se ve, y a 4 px sigue siendo un borde y no un recuadro.

El halo lleva **el mismo radio que el borde**, no uno menor. `DecoratedBox` no
mete a su hijo dentro del borde —eso solo lo hace `Container`—, así que los dos
trazos comparten rectángulo: bajarle el radio al halo para "hacerlo concéntrico"
lo convierte en el contorno más exterior de las esquinas, y entonces es **el
halo, y no el borde, quien decide** hasta qué redondeo de pantalla cabe el marco.
Con radio 40 sobre margen 4 el halo aguantaba hasta 53, por debajo de los 55 del
teléfono donde se detectó el problema: la primera versión de este delta arreglaba
el borde y dejaba la banda tenue cortándose igual.

Para ser exactos: con el margen de 6 que fija DD1, un halo de radio 52 también
cabría —el corte a 53 salía de la combinación margen 4 + radio 40, no de bajar el
radio por sí solo—. Compartir radio se elige porque hace coincidir los dos
contornos y deja una sola holgura que vigilar en vez de dos, no porque la
alternativa sea inviable.

Con el mismo radio los dos contornos coinciden y los trazos se apilan hacia
dentro: 4 px opacos y 4 px de banda tenue asomando, 8 px de aviso en total. Que
se solapen es lo que mantiene el conjunto fino; separarlos con un `Padding`
sumaría 12 px y dejaría de ser "un pelín".

### DD3 — El doble toque deshace el pin de su primer toque

Se invierte D13 del padre. Se guarda el pin que había **antes** del primer toque
de la pareja; al confirmarse el doble toque se restaura (`colocarPin` si había
uno, `limpiarPin` si no) y solo entonces se acerca. No hace falta API nueva en
el controlador.

El motivo es de intención, no de comodidad: "acércame aquí" y "mi respuesta es
aquí" son dos cosas distintas, y con D13 un jugador que ya tenía su respuesta
puesta y hacía doble toque en otra zona para mirarla de cerca **perdía la
respuesta**. Eso pesa mucho más que la comodidad de heredar el pin.

La consecuencia visible es que en un doble toque el pin aparece y desaparece en
menos de 300 ms. Se acepta a cambio de no tocar la inmediatez del toque simple:

- Alternativa descartada: mover el pin a después del plazo de doble toque, para
  que en un doble toque no llegue a aparecer. Son 300 ms de retardo en la acción
  principal de la pantalla — exactamente lo que D9 del padre evitó, y lo que hace
  que colocar el pin se sienta inmediato.
- Alternativa descartada: dejar el pin del primer toque quieto en su sitio (sin
  restaurar). Más simple, pero un doble toque sobre un mapa sin pin seguiría
  dejando pin, que es justo lo que se pide quitar.

### DD4 — Olvidar el pin recordado cuando se olvida el toque

El recuerdo del pin previo vive y muere con el recuerdo del toque previo: lo
limpia el mismo `_olvidarElToque` que ya corre al expirar el plazo, al
completarse un doble toque y al pasar el mapa a no interactivo. Así no puede
resucitar un pin viejo después de que la pantalla lo haya limpiado al avanzar de
desafío.

## Risks / Trade-offs

- **El pin parpadea en un doble toque** (≤300 ms) → aceptado en DD3. Si en
  prueba resulta molesto, la salida es DD3-alternativa-1 (retrasar el pin) con el
  coste que allí se explica.
- **El radio 44 no es el del teléfono** → puede quedar un hilo de fondo entre el
  marco y el canto en un dispositivo muy redondeado. Es un marco decorativo: que
  sobre un poco de aire es infinitamente mejor que que se corte.
- **Dos toques cercanos hechos a propósito para mover el pin unos píxeles** ahora
  no mueven el pin, lo devuelven a su sitio y acercan. Es el precio de que el
  gesto exista; el slop de 40 px lo mantiene raro.
