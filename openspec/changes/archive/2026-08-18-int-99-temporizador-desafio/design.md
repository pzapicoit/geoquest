## Context

Estado verificado del backend (ver proposal.md): `respuestas_desafio` no
guarda tiempo, `niveles` no tiene columna de segundos, y `calcular_puntaje`
(INT-101) es `PISO + (MAX - PISO) * exp(-distancia_km / K)` con
`MAX=5000, PISO=50, K=1500`, sin ningún otro factor. `responder_desafio`
(INT-93) exige lat/lng no nulos y es `security definer` porque necesita leer
`desafios.lat_real/lng_real`, que RLS esconde del jugador. El trigger
`respuestas_desafio_antes_de_insertar` (INT-78) recalcula siempre
`distancia_km`/`puntos` en el servidor, ignorando lo que llegue en el
`insert`, para que ninguna vía de escritura pueda falsear el resultado.

`intento_desafios` (INT-100) ya persiste, por intento, qué desafíos tocaron
y en qué orden, pero no tiene ninguna marca de tiempo; su RLS solo permite
`select`/`insert` de las filas propias, nunca `update`.

En el panel, `panel/src/lib/nivelRecorrido.ts` duplica las constantes de la
curva (`MAX_PUNTOS_DESAFIO=5000`, `PISO_PUNTOS_DESAFIO=50`,
`K_DISTANCIA_KM=1500`) para invertir la curva y mostrar, junto a cada
umbral, la distancia media en km que implica alcanzarlo
(`distanciaMediaKm`, `panel-level-detail`).

En la app, `nivel_juego_screen.dart` es un único `StatefulWidget`
(`_NivelJuegoScreenState`) con índice `_indice` (desafío actual),
`_pistaVisible` (toast abierto) y `_revelado` (no nulo durante el
revelado). Ya usa `Timer` para temporizar el aviso de error
(`_temporizadorDelMensaje`). El HUD (`_HudJuego` → `_TarjetaDeProgreso`)
define las paradas de color `_teal`, `_gold`, `_rojo` que el mock de diseño
pide para la cuenta atrás.

Decisiones de producto ya tomadas (fuera del alcance de este documento,
resueltas antes de escribir la propuesta):
1. El límite de tiempo es por desafío, no por intento.
2. Se configura por nivel.
3. Al llegar a 0: si hay pin colocado, se auto-confirma; si no, se registra
   0 puntos sin coordenadas.
4. El tiempo puntúa (bonus por rapidez), con rebalanceo de niveles
   existentes.

## Goals / Non-Goals

**Goals:**
- Medir el tiempo transcurrido por desafío de forma que el servidor sea la
  única fuente de verdad, igual que ya ocurre con distancia y puntos.
- Mantener el invariante de `challenge-scoring` de que ninguna vía de
  escritura pueda falsear el puntaje persistido.
- Que una app ya desplegada (sin el nuevo gateway) siga funcionando durante
  la ventana de despliegue, sin bonus de tiempo.
- Dejar los niveles existentes con una dificultad relativa equivalente a la
  que tenían antes del bonus.

**Non-Goals:**
- No se define aquí el límite de tiempo por intento completo (descartado
  como decisión de producto).
- No se implementa un modo "sin temporizador" por nivel (ver Open
  Questions).
- No se toca la curva de distancia en sí (`MAX=5000, PISO=50, K=1500`), solo
  se le añade un bonus.

## Decisions

**D1 — Medición server-authoritative del tiempo, no un valor que mande el
cliente.** Nueva columna `intento_desafios.mostrado_en timestamptz`,
fijada por una RPC dedicada (`marcar_desafio_mostrado`) cuando el desafío
se vuelve el actual. El tiempo transcurrido se calcula siempre como
`now() - mostrado_en` en el momento de `responder_desafio`, nunca a partir
de un "segundos restantes" que mande la app.
*Alternativa descartada*: que la app mande los segundos consumidos al
confirmar. Se descarta porque sería tan falseable como lo era
`distancia_km`/`puntos` antes de INT-78 — exactamente el problema que ese
trigger ya resuelve para distancia y puntos.

**D2 — RPC nueva (`marcar_desafio_mostrado`) en vez de ampliar
`iniciar_intento_nivel`.** Cada desafío se "muestra" en un instante
distinto del intento (cuando el jugador abre su pista), no todos al
arrancar la partida.
*Alternativa descartada*: derivar el inicio del desafío N a partir del
`respondido_en` del desafío N-1. Se descarta porque el primer desafío no
tiene "anterior", y porque reabrir la pista de un desafío ya mostrado no
debería reiniciar su cronómetro.

**D3 — Excepción controlada a "intento_desafios no admite `update`".** La
RPC es `security definer`, valida a mano que el intento pertenece a
`auth.uid()` (mismo patrón que `responder_desafio`), y solo hace
`update ... where intento_id = ... and desafio_id = ... and mostrado_en is
null` — idempotente: reabrir una pista ya mostrada no reinicia el
cronómetro. La prohibición de `update` directo por RLS no cambia; solo esta
RPC, que corre con sus propias comprobaciones, tiene esta vía.

**D4 — Fórmula del bonus: escalado por acierto y por tiempo restante, no
solo por tiempo.** Para no premiar una respuesta rápida pero muy alejada:

```
puntos_base          := calcular_puntaje_por_distancia(distancia_km)   -- curva existente, sin tocar
fraccion_acierto     := (puntos_base - PISO) / (MAX - PISO)            -- 0 en el suelo, 1 a distancia 0
fraccion_tiempo      := clamp((segundos_por_desafio - segundos_transcurridos) / segundos_por_desafio, 0, 1)
bonus_max            := 500                                            -- 10% del máximo actual (5000)
bonus                := round(bonus_max * fraccion_tiempo * fraccion_acierto)
puntos               := puntos_base + bonus                            -- máximo por desafío: 5000 -> 5500
```

*Alternativa descartada*: multiplicar el puntaje base por un factor de
tiempo (p.ej. ×1.1) en vez de sumar un bonus acotado. Se descarta porque
también escalaría `PISO`, rompiendo el invariante "el puntaje nunca baja de
50" de `challenge-scoring` salvo que se reescale el propio suelo — más
complejo de razonar y de migrar que un bonus aditivo acotado.

**D5 — `calcular_puntaje` cambia de firma (drop + create, no
`create or replace`).** Pasa de `calcular_puntaje(distancia_km)` a
`calcular_puntaje(distancia_km, segundos_transcurridos,
segundos_por_desafio)`. La curva pura de distancia se conserva, sin cambiar
su cuerpo, en una función interna `calcular_puntaje_por_distancia(distancia_km)`
que la nueva función reutiliza. Mismo patrón que el cambio de firma de
`responder_desafio` en INT-93 (`drop function` + `create function`, porque
Postgres no permite `create or replace` cuando cambia la lista de
argumentos).

**D6 — `segundos_transcurridos` siempre recalculado en el servidor,** igual
que `distancia_km`/`puntos` (INT-78): `segundos_transcurridos :=
least(segundos_por_desafio, greatest(0, floor(extract(epoch from (now() -
mostrado_en)))))`. Si `mostrado_en` es `null` (la app no llamó a
`marcar_desafio_mostrado` — app vieja, o intento anterior a esta
migración), se trata como tiempo agotado (`segundos_transcurridos :=
segundos_por_desafio`, `fraccion_tiempo = 0`, bonus = 0) en vez de fallar la
respuesta: una app vieja sigue pudiendo jugar, solo sin bonus.

**D7 — Caso sin pin al agotar el tiempo: parámetros opcionales, no una RPC
aparte.** `responder_desafio(p_intento_id, p_desafio_id, p_lat_adivinada
default null, p_lng_adivinada default null)`. Cuando ambos son `null`,
`distancia_km` queda `null` y `puntos = 0` sin llamar a la curva de
distancia (el bonus tampoco aplica: no hay acierto que premiar). Los checks
de `respuestas_desafio` se relajan para admitir `lat_adivinada`/
`lng_adivinada`/`distancia_km` nulos, pero exigiendo que las dos
coordenadas sean nulas a la vez (nunca solo una).

**D8 — La auto-confirmación con pin colocado no es un cambio de backend.**
Vista desde el servidor es una llamada normal a `responder_desafio` con las
coordenadas del pin ya puesto. Que se dispare sola al llegar a 0 (en vez de
por un toque en "Confirmar") es una decisión de la app, documentada en el
delta de `app-game-screen`, no una rama nueva de la RPC.

**D9 — Rebalanceo de niveles existentes: ×1.1 sobre los cuatro campos.** La
misma migración que sube el máximo por desafío de 5000 a 5500 actualiza
`puntaje_minimo_superar`, `umbral_estrella_1/2/3` de todos los niveles
existentes multiplicando por 1.1 y redondeando, para que conserven el mismo
porcentaje del máximo que tenían antes (`panel-level-detail` ya expresa
estos umbrales como porcentaje del máximo del nivel al editarlos, así que
esto es aplicar ese mismo porcentaje al nuevo máximo).
*Alternativa descartada*: dejar los umbrales sin tocar. Se descarta porque
haría el juego notablemente más fácil (mismo umbral, más puntos
disponibles) sin que ningún admin lo haya decidido.

**D10 — Colores del HUD: reutilizar `_teal`/`_gold`/`_rojo` ya definidos en
`nivel_juego_screen.dart`,** con corte en 50%/20% del tiempo restante
(verde >50%, ámbar 20–50%, rojo <20%). El mock original
(`[App] - Pantalla de juego - Mapa.dc.html`) no está disponible en este
repo para confirmar los cortes exactos; son un punto de partida razonable,
ajustable sin tocar backend.

**D11 — El contador visual arranca cuando el desafío se vuelve el actual**
(mismo instante en que se llama a `marcar_desafio_mostrado`: al recibir la
respuesta de `iniciar_intento_nivel` para el primer desafío, y en
`_avanzarDesdeElRevelado` para los siguientes), y sigue corriendo con la
pista abierta — coherente con que el resto del HUD ya es visible "por
encima del toast" (`app-game-screen`).

**D12 — El panel usa dos constantes de máximo distintas, no una.**
`MAX_PUNTOS_DESAFIO` (la que convierte porcentaje ⇄ absoluto de
`puntaje_minimo_superar`/`umbral_estrella_2/3`, y la que consume el
rebalanceo ×1.1 de D9) sube de 5000 a 5500, para que el mismo porcentaje
mostrado en el formulario siga significando lo mismo tras el rebalanceo
(`nuevo_absoluto = viejo_absoluto × 1.1`, `nuevo_absoluto / (N × 5500) =
viejo_absoluto / (N × 5000)`, es decir, el `%` en pantalla no cambia).
`distanciaMediaKm`, en cambio, sigue invirtiendo solo la curva de distancia
con sus constantes de siempre (`MAX_PUNTOS_DISTANCIA=5000, PISO=50,
K=1500`, sin tocar) — el peor caso, sin bonus.
*Alternativa descartada*: una sola constante de 5500 para todo, incluida
`distanciaMediaKm`. Se descarta porque ese campo orienta al admin sobre la
precisión mínima necesaria; invertir sobre 5500 mostraría una distancia más
permisiva de la que hace falta si el jugador no llega a tiempo.

**D13 — Revelado sin pin: variante simplificada, no la coreografía
completa.** Cuando el tiempo se agota sin pin colocado, el revelado SHALL
mostrar únicamente la ubicación real y los puntos (0), sin pin del jugador,
sin línea punteada y sin contador de distancia (no hay `distancia_km` que
mostrar). Es una variante del mismo `_HojaDeRevelado`, no una pantalla
nueva.
*Alternativa descartada*: forzar un pin "fantasma" en el centro del mapa
para poder reutilizar la coreografía completa sin ramas. Se descarta por
ser una distancia inventada que no sale de ningún cálculo del servidor,
contradiciendo el mismo invariante que motiva D1/D6.

## Risks / Trade-offs

- [Riesgo] Una app que no llama a `marcar_desafio_mostrado` (bug, o versión
  vieja en producción durante el despliegue) pierde el bonus siempre →
  Mitigación: D6, degrada a "sin bonus", no bloquea ni falla la partida.
- [Riesgo] Latencia de red entre que el servidor marca `mostrado_en` y el
  jugador ve realmente la pista puede hacer que el contador visual y el
  bonus real no coincidan al segundo → Mitigación: el contador visual es
  solo un indicador; el bonus lo decide siempre el servidor, igual que ya
  pasa con distancia/puntos frente al mapa del cliente.
- [Riesgo] Cambiar la firma de `calcular_puntaje` y `responder_desafio` es
  incompatible con cualquier llamador ya desplegado → Mitigación: mismo
  patrón que INT-93; migración de backend y despliegue de la app van en el
  mismo release (ver Migration Plan).
- [Riesgo] El rebalanceo automático (×1.1) puede no ser exactamente lo que
  cada nivel concreto necesita → Mitigación: es una migración de datos
  documentada y reversible (÷1.1); cualquier nivel se puede reajustar
  después a mano desde el panel.

## Migration Plan

1. Una única migración SQL que, en este orden: añade las columnas nuevas
   (`niveles.segundos_por_desafio`, `intento_desafios.mostrado_en`,
   `respuestas_desafio.segundos_transcurridos`), relaja los checks de
   `respuestas_desafio` para coordenadas/distancia nulas, crea
   `calcular_puntaje_por_distancia` y la nueva `calcular_puntaje` (drop +
   create), reemplaza el trigger y `responder_desafio`, crea
   `marcar_desafio_mostrado`, y por último rebalancea (×1.1) los niveles
   existentes. Todo en una migración para que no haya una ventana donde el
   trigger nuevo dependa de columnas que aún no existen.
2. Backend + panel se despliegan primero: no rompen nada por sí solos. La
   app vieja sigue llamando a `responder_desafio` con coordenadas no nulas
   (sigue aceptándolas) y nunca llama a `marcar_desafio_mostrado`, así que
   juega sin bonus (D6) hasta que se actualice.
3. La app se despliega con el gateway nuevo (parámetros opcionales +
   `marcar_desafio_mostrado`) y la UI del temporizador.
4. Rollback: revertir implicaría volver `calcular_puntaje`/
   `responder_desafio` a su firma anterior (drop + create de vuelta) y
   deshacer el rebalanceo (÷1.1, redondeando igual). Documentar ese SQL de
   vuelta como comentario en la propia migración.

**D14 — El revelado desglosa el puntaje en precisión y bonus, no solo el
total.** La respuesta de `responder_desafio` añade `puntos_distancia`
(componente de distancia, el mismo valor que devolvería
`calcular_puntaje_por_distancia(distancia_km)`) y `puntos_bonus`
(`puntos - puntos_distancia`) junto al `puntos` total que ya devolvía.
Ninguna columna nueva en `respuestas_desafio`: el desglose se deriva en la
propia RPC a partir de valores que ya tiene calculados, solo para
enriquecer la respuesta que consume la app. Cuando la respuesta es sin pin
(timeout sin pin colocado), ambos campos son `0`, coherente con
`puntos = 0`.
*Motivo*: sin desglose, un jugador ve una puntuación más alta de lo
esperado sin entender por qué; mostrar "+80 por rapidez" en el revelado
conecta la presión de tiempo con la recompensa, reforzando la mecánica en
vez de que pase desapercibida.

## Decisiones confirmadas en la revisión de esta propuesta

- Ningún nivel queda sin temporizador: `segundos_por_desafio` se mantiene
  `not null default 60` tal como en D-tasks 1.1; no hace falta una
  variante "sin límite".
- Los valores de partida se confirman tal cual: bonus máximo `500` (10%
  del máximo de distancia, `5000`) y cortes de color de la cuenta atrás en
  50%/20% del tiempo restante (D10). Ajustables más adelante sin tocar el
  resto de la arquitectura si el mock original difiere.
