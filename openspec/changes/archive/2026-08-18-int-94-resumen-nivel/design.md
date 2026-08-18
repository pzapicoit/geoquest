## Context

Tras INT-93 la pantalla de juego revela cada desafío pero, al llegar al
último, "Ver resultados" hace `Navigator.of(context).pop()` sin más — un
placeholder dejado a propósito (D8 y Open Question de `design.md` de
INT-93) hasta que existiera lógica de superación que cerrar (INT-79, ya
existente) y un `cerrar_intento_nivel` capaz de cerrar cualquier intento
real (INT-100, ya resuelto). Esta pieza cierra ese hueco: cerrar el
intento y enseñar su resultado.

El diseño de referencia es `[App] - Resumen del nivel.dc.html` (Claude
Design), con dos variantes sobre el mismo layout de pantalla completa:

- **10a — superado**: pill "Nivel N · Zona", título de celebración, 3
  huecos de estrella (tamaños 78/104/78 px) que se rellenan una a una
  (420 ms + 480 ms por estrella) con confeti al terminar si son 3,
  puntaje grande, aviso opcional de récord (entra 1,5 s después de
  arrancar) y botón "Continuar".
- **10b — no superado**: mismo layout sin estrellas encendidas, tarjeta de
  "cuánto faltó" con barra de progreso hacia el mínimo, botón "Reintentar"
  y enlace "Volver al camino".

Lo que ya existe y se reutiliza tal cual: `cerrar_intento_nivel` (INT-79,
corregido en INT-100), `progreso_usuario_nivel` con `mejor_puntaje`/
`mejores_estrellas` (INT-74), y el patrón de gateway con mapeadores puros
+ modelos inmutables de `nivel_juego_gateway.dart` (INT-91/INT-93).

Lo que falta y este cambio añade: la propia función no devuelve nada que
sirva para "cuánto faltó" (`puntaje_minimo_superar` del nivel) ni para
"nuevo récord personal" (el `mejor_puntaje` que tenía el jugador *antes*
de este cierre — después de la función ya no se puede leer, porque la
misma función lo sobrescribe con `greatest(...)`).

## Goals / Non-Goals

**Goals:**
- Cerrar el intento al terminar el último desafío y enseñar el resultado
  fiel al mockup, en sus dos estados.
- Detectar "nuevo récord personal" sin una segunda llamada ni condición de
  carrera con la propia actualización de `progreso_usuario_nivel`.
- Que "Reintentar" arranque una partida nueva del mismo nivel sin arrastrar
  estado de la partida anterior (mapa, animaciones, controladores).
- Que el camino refleje el resultado (estrellas, desbloqueos) al volver,
  sin exigir reabrir la app.

**Non-Goals:**
- Tocar la lógica de superación/estrellas/desbloqueos en sí (INT-79): esta
  pieza solo enseña lo que esa lógica ya decide.
- Historial de intentos anteriores del nivel, más allá del mejor puntaje
  para el aviso de récord.
- Compartir el resultado o cualquier mecánica social.
- Sonido: el mockup no lo pide y no hay assets de audio en el proyecto.

## Decisions

**D1 — `cerrar_intento_nivel` devuelve `jsonb` en vez de la fila cruda de
`intentos_nivel`.** El tipo de retorno actual no trae ni el mínimo del
nivel ni el mejor puntaje previo, y no se puede ampliar sin cambiar de
tipo — mismo caso que D1 de INT-93 con `responder_desafio`. Alternativas
descartadas: (a) que la app haga dos `select` propios (`niveles` y
`progreso_usuario_nivel`) antes de cerrar — dos viajes de red más y una
ventana entre leer el mejor puntaje previo y que el propio cierre lo
sobrescriba, si el jugador cerrara el mismo intento dos veces a la vez
(doble tap, reintento tras timeout); (b) una función auxiliar
`resumen_intento(id)` de solo lectura tras el cierre — sigue exigiendo
leer el "antes" en algún momento anterior al cierre. Se elige ampliar el
`jsonb` de la propia función, que ya calcula puntaje/superado/estrellas y
ya tiene el mínimo del nivel en una variable local. Coste: `drop function`
+ `create` (Postgres no permite `create or replace` con tipo de retorno
distinto), único consumidor la propia app, que aún no llama a la función
en producción.

**D2 — `mejor_puntaje_anterior` viaja como `NULL` cuando no existe fila
previa de `progreso_usuario_nivel`, no como `0`.** El criterio del ticket
es "nuevo récord si mejora un resultado anterior": en el primer intento de
un nivel no hay un resultado anterior que mejorar, así que no hay récord
que anunciar, por trivial que sea "más que 0". Se captura con un `select`
a `progreso_usuario_nivel` *antes* del `insert ... on conflict do update`
que ya hace la función — en la misma transacción, así que no hay ventana
de carrera con otro cierre concurrente del mismo usuario (el
`pg_advisory_xact_lock` que ya toma la función para el desbloqueo del
camino cubre igual este caso si se necesitara, pero al ser una lectura
dentro de la misma transacción del propio `intento_id` no hace falta
adelantar el lock).

**D3 — El aviso de récord exige estar superado, tener anterior y
mejorarlo.** `isRecord = superado && mejorPuntajeAnterior != null &&
puntajeTotal > mejorPuntajeAnterior`. Empatar el mejor puntaje previo no
cuenta como récord (`>`, no `>=`), igual que el propio
`progreso_usuario_nivel` solo sube con `greatest`.

**D4 — El camino pasa `orden` y `tematicaNombre` a la pantalla de juego,
además del `nivelNombre` que ya pasaba.** El pill "Nivel N · Zona" del
resumen necesita ambos y el camino ya los tiene cargados (misma razón que
D9 de `design.md` de INT-92 para `nivelNombre`): pedirlos de nuevo sería
una consulta que ya se ha hecho. El total de desafíos no necesita plumbing
nuevo: la pantalla de juego ya conoce `desafios.length` del intento en
curso.

**D5 — "Reintentar" es una pantalla de juego nueva (`pushReplacement`), no
un reset del estado de la anterior.** La pantalla que se reintenta ya
tiene su `AnimationController` de la coreografía del revelado, su
`MapaMundiController` y su `Timer` de avisos en curso de `dispose`;
reconstruirla desde cero con `NivelJuegoScreen(nivelId: ...)` reutiliza
`initState` → `iniciar_intento_nivel` tal cual existe hoy, sin un segundo
camino para "reiniciar" que pueda desincronizarse del primero.

**D6 — Navegación encadenada con `pushReplacement`, camino recarga con un
`RouteObserver`, no con el `.then()` del `push` original.** `camino_screen`
→ `push` → `NivelJuegoScreen` → (último desafío) `pushReplacement` →
`ResumenNivelScreen` → `Continuar`/`Volver al camino` hacen `pop` (vuelven
al camino) o, desde el estado no superado, `Reintentar` hace
`pushReplacement` a un `NivelJuegoScreen` nuevo — que a su vez puede volver
a cerrar un intento y `pushReplacement` a un `ResumenNivelScreen` nuevo. Un
`.then()` sobre el `push` original no sirve para disparar la recarga:
`pushReplacement` completa el `Future` de la ruta que reemplaza en cuanto
la reemplaza, no cuando el jugador realmente abandona la cadena — con
"Reintentar" de por medio, ese `Future` se resuelve en el primer
reemplazo (`NivelJuegoScreen` → `ResumenNivelScreen`), mucho antes de que
el segundo intento (el que de verdad importa al volver) exista siquiera.
En su lugar, `camino_screen` se suscribe como `RouteAware` a un
`RouteObserver<PageRoute>` compartido (`lib/route_observer.dart`, colgado
del `Navigator` raíz vía `MaterialApp.navigatorObservers`) y recarga en
`didPopNext()`, que se dispara exactamente cuando esta pantalla vuelve a
ser la visible — sea cual sea la cadena de `push`/`pushReplacement` que
haya habido por encima — en vez de en un punto intermedio arbitrario. Se
recarga siempre al volver, también si el jugador solo entró y salió sin
terminar, porque es más simple que distinguir casos y recargar una vista
ya cargada no tiene coste percibido.

**D7 — Paleta y tipografías del mockup, duplicadas como consts privados en
el nuevo archivo.** Mismos valores que ya usan `nivel_juego_screen.dart`,
`camino_screen.dart` y `username_screen.dart` (`_ink #0E1620`, `_teal
#2BC0A8`, `_azul #1B6FA8`, `_gold #FFC53D`/`#FFE9A8`, `GoogleFonts.baloo2`/
`.outfit`) — cada pantalla ya los duplica en vez de compartir un módulo de
tema; se sigue el mismo patrón en vez de introducir esa abstracción para
esta pieza sola.

**D8 — La coreografía de estrellas es una cadena de `Timer`, no un
`AnimationController` con tramos.** A diferencia del revelado (D4 de
INT-93, que necesita interpolar cámara y contadores de forma continua y
recortable en cualquier instante), aquí cada estrella es un salto discreto
de apagada a encendida — el mismo patrón que usa el propio mock
(`setTimeout` encadenados). Un `StatefulWidget` guarda cuántas estrellas
lleva mostradas y dispara un `Timer` por estrella (420 ms + 480 ms ×
posición) más uno para el confeti; "Repetir animación" cancela los
`Timer` en curso y vuelve a lanzarlos desde cero, sin llamar de nuevo al
servidor (mismo principio que D11 de INT-93). Todos los `Timer` se
cancelan en `dispose`.

**D9 — El confeti se pinta a mano, sin paquete nuevo.** El proyecto no
trae ningún paquete de confeti/partículas y añadir uno para 30 piezas que
caen una vez es desproporcionado. Se reproduce el generador
pseudo-aleatorio determinista del propio mock (seno del índice como
semilla) para las 30 piezas — posición, tamaño, color, retraso y
duración — con `AnimatedBuilder` + `Transform.translate`/`Opacity` por
pieza, igual que el resto de animaciones a medida del proyecto
(`_PuntoQueLate`, `_Destello`).

**D10 — El texto de ejemplo del mock bajo la barra de "cuánto faltó" no
se copia literal.** "Ya tienes el 90% del mínimo del nivel. Afinar dos
pines te sobra para pasarlo." es contenido de ejemplo atado a las cifras
de ese mock, no una copia exigida por el ticket ("mensaje de ánimo, tono
positivo"). Se sustituye por un texto genérico que no de por hecho cuántos
pines le faltaron, que solo depende del porcentaje ya calculado.

**D11 — El intento se cierra al pulsar "Ver resultados" del último
desafío, no antes.** Es el único punto en que la pantalla sabe con
certeza que el jugador ya vio el revelado de todos los desafíos y decidió
seguir — cerrar antes (p. ej. nada más recibir la respuesta del último
`responder_desafio`) adelantaría el resultado a un momento en que el
jugador todavía está mirando la revelación anterior. Mientras la llamada
está en curso el botón queda deshabilitado (mismo patrón que `_enviando`
en `_confirmar`), y si falla se avisa y se conserva el revelado en
pantalla para reintentar, sin perder ningún dato local.

## Risks / Trade-offs

- **[Riesgo] `drop function` + `create` deja `cerrar_intento_nivel`
  inexistente unos milisegundos** → Mitigación: no hay build publicada
  todavía, solo desarrollo (mismo razonamiento que D14/Migration Plan de
  INT-93).
- **[Riesgo] La app se cierra justo después de cerrar el intento pero
  antes de pintar el resumen** → El intento ya quedó cerrado en el
  servidor (estrellas y progreso persistidos); el jugador solo pierde ver
  la celebración, no el resultado. Se acepta: es el mismo trade-off que
  cualquier confirmación de servidor sin pantalla de éxito garantizada.
- **[Riesgo] Confeti hecho a mano en 30 `AnimatedBuilder` puede notarse en
  gama baja** → Mitigación: son piezas sin `Path` complejo (rectángulos y
  círculos), la misma clase de coste que `_Destello`/`_PuntoQueLate`, que
  ya conviven con el mapa animado del revelado.
- **[Trade-off] Recargar el camino siempre al volver de jugar** (haya
  cambiado algo o no) es una consulta de más comparado con recargar solo
  cuando el resultado lo justifica → Se acepta por simplicidad: distinguir
  "hubo cambio" desde fuera de `camino_screen` exigiría propagar el
  resultado del intento de vuelta por la pila de navegación.

## Migration Plan

1. `supabase db push` de la migración nueva: `drop function
   cerrar_intento_nivel(uuid)` y `create` de la versión que devuelve
   `jsonb`, capturando `mejor_puntaje_anterior` antes del upsert de
   `progreso_usuario_nivel`, con su `revoke`/`grant` de siempre.
2. Desplegar la app después del backend, mismo orden que INT-93: la app
   nueva no funciona con la RPC vieja ni al revés.
3. Sin migración de datos: ninguna tabla cambia de forma.
4. Revertir es volver al commit anterior y aplicar una migración que
   restaure la firma antigua (`returns intentos_nivel`); los intentos
   cerrados mientras tanto no se ven afectados, porque lo que cambia es
   solo el contrato de salida, no lo que se persiste.

## Open Questions

- ¿"Repetir animación" en el estado superado debe estar, como en el mock,
  o sobra ahora que no hay revelado de un solo desafío que repasar? Se
  incluye por fidelidad al diseño; quitarla es un cambio de una línea si
  se decide lo contrario.
- ¿El aviso de récord debe distinguirse de alguna forma cuando el
  jugador ya tenía el nivel superado de antes (mejora su marca) frente a
  cuando lo supera por primera vez con un resultado que además es su
  mejor puntaje? Con D2/D3 ambos casos muestran el mismo aviso; se puede
  matizar el texto si en pruebas se ve confuso.
