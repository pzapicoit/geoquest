## Why

Hoy confirmar el pin es un acto de fe: la app manda la respuesta, suma unos
puntos que aparecen de la nada en el HUD y salta a la pista siguiente. El
jugador no ve dónde estaba el sitio, ni cuánto se desvió, ni por qué le han
dado esos puntos. Ese momento —"casi, estaba 247 km más al este"— es el
gancho del género y lo único que convierte una respuesta en aprendizaje;
sin él, GeoQuest es un formulario de coordenadas.

Además hay un hueco de backend que arrastramos desde INT-78:
`responder_desafio` calcula distancia y puntos pero no devuelve la
ubicación real ni el nombre del lugar, porque RLS los esconde del jugador
(INT-77). Sin abrir ese dato —solo para el desafío que se acaba de
responder— la pantalla de revelado no se puede construir.

## What Changes

- **BREAKING (interno): `responder_desafio` pasa a devolver `jsonb`** en vez
  de una fila de `respuestas_desafio`. La respuesta incluye lo de siempre
  (`distancia_km`, `puntos`, la fila registrada) más el revelado del desafío
  respondido: `lat_real`, `lng_real`, `nombre_lugar` y `puntos_maximos`. Se
  revela **solo** en la respuesta a la propia jugada, que es irrepetible
  dentro del intento por el `unique (intento_id, desafio_id)`; ni la vista
  `desafios_para_jugar` ni `iniciar_intento_nivel` cambian, y `desafios`
  sigue sin política de `select` para jugadores.
- **Fase de revelado en la pantalla de juego**: confirmar ya no salta al
  desafío siguiente, sino que revela el resultado sobre el mismo mapa, con
  una coreografía que corre sola: aparece el pin de la ubicación real junto
  al del jugador, la cámara encuadra los dos con margen, se traza una línea
  punteada entre ellos y suben los contadores de distancia y de puntos.
- **Hoja de resultado** sobre el mapa: miniatura de la pista original,
  "Ubicación real" con el nombre del lugar y sus coordenadas, tarjeta de
  "Te has desviado" (km) y tarjeta de "Has ganado" (puntos sobre el máximo),
  botón "Siguiente" —"Ver resultados" en el último desafío del nivel— y un
  "Repetir animación" que relanza la secuencia.
- **El HUD se actualiza con la jugada**: el puntaje total del intento sube
  a la vez que el contador de puntos, y el segmento del desafío respondido
  pasa a contar como resuelto.
- **Segundo pin, encuadre automático y línea punteada en el mapa**: el mapa
  aprende a mostrar la ubicación real, a encuadrar dos coordenadas con
  márgenes distintos arriba y abajo (para que ningún pin quede debajo de la
  hoja de resultado) y a dibujar la línea del gran círculo entre ambos
  pines de forma progresiva. Durante el revelado el mapa deja de aceptar
  gestos: la jugada ya está cerrada.
- La **pantalla de resumen del nivel** sigue fuera de alcance (INT-94):
  "Ver resultados" vuelve al camino de niveles, igual que hoy.

## Capabilities

### New Capabilities
(ninguna — el revelado es una fase más de la pantalla de juego y del mapa
que ya existen; no aparece ninguna superficie nueva del producto.)

### Modified Capabilities
- `challenge-scoring`: `responder_desafio` deja de ser opaca sobre la
  ubicación real y pasa a revelar `lat_real`/`lng_real`/`nombre_lugar` del
  desafío respondido —y el puntaje máximo alcanzable— en la respuesta de la
  propia jugada; cambia además su tipo de retorno a `jsonb`.
- `app-game-screen`: confirmar entra en la fase de revelado en vez de
  avanzar; el avance al desafío siguiente pasa a ser un acto explícito del
  jugador ("Siguiente"); el puntaje del HUD se actualiza durante el
  revelado.
- `app-world-map`: el mapa gana el pin de la ubicación real, el encuadre
  automático de dos coordenadas con márgenes y la línea punteada progresiva
  entre ambas, y la posibilidad de quedar en modo no interactivo.

## Impact

- `backend/supabase/migrations/`: migración nueva que reemplaza
  `responder_desafio` (`drop function` + `create`, el tipo de retorno
  cambia). El trigger `respuestas_desafio_antes_de_insertar` y las funciones
  de cálculo no se tocan.
- `app/lib/services/nivel_juego_gateway.dart`: `RespuestaDesafio` gana
  ubicación real, nombre del lugar y puntos máximos; el mapeo pasa a leer
  el `jsonb` nuevo.
- `app/lib/mapa/mapa_mundi_controller.dart`: pin real, cámara aplicable
  desde fuera, cálculo de encuadre para varias coordenadas con márgenes y
  progreso de la línea.
- `app/lib/mapa/` (nuevo): interpolación del gran círculo y troceado de la
  línea punteada, como funciones puras probables sin widgets.
- `app/lib/mapa/mapa_mundi.dart`: dibujo del pin real y de la línea, modo
  no interactivo.
- `app/lib/screens/nivel_juego_screen.dart`: fase de revelado con su
  coreografía, hoja de resultado, contadores animados y avance explícito.
- `app/test/`: fakes actualizados y tests de encuadre, línea punteada,
  mapeo del `jsonb`, contadores, avance con "Siguiente" y "Ver resultados"
  en el último desafío.
- Sin dependencias nuevas ni cambios en el panel.
