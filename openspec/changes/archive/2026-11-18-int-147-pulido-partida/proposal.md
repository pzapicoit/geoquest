## Why

Jugando una partida completa en tamaño móvil (390×844) aparecen detalles que
restan calidad a una interfaz que, por lo demás, está muy cuidada:

- textos cortados en las dos cabeceras («RutaSal…», «Desafío 2 d…»,
  «MONUMENTOS …»);
- rótulos del mapa que se salen por los bordes;
- una hoja de resultado que dice «0,0 km» y «+0» mientras ya enseña los puntos
  reales debajo;
- un resumen que dice «¡Estás cerca!» con un 38 % del mínimo;
- copy impreciso: «FOTO» cuando son ilustraciones, la pista que repite la
  instrucción, «Peliculas · Peliculas»;
- dos botones sin nombre para el lector de pantalla.

## What Changes

- **Cabecera del camino**: el apodo y la línea de progreso se encogen para caber
  en vez de cortarse, y el progreso se compacta («Nivel 1/8 · 0/24 ★»).
- **Cabecera de la partida**: «Desafío N de M» en una línea y el nombre de la
  parada en la suya propia, sin compartir el ancho.
- **Rótulos de los pines**: centrados sobre el pin, pero desplazados lo justo
  para quedar dentro del mapa.
- **Hoja de resultado**:
  - distancia y puntos muestran «—» hasta que empieza su contador;
  - el desglose de precisión y bonus aparece a la vez que cuentan los puntos.
- **Resumen no superado**: el título y el ánimo dependen de lo cerca que se
  quedó el jugador. «¡Casi lo tienes!» solo desde el 80 % del mínimo.
- **Copy de la pista**:
  - «IMAGEN · PISTA N» en vez de «FOTO»;
  - la instrucción fija deja de repetir la pregunta: queda «Coloca tu pin lo
    más cerca que puedas.».
- **Bienvenida**: «Siguiente: X · Y» no repite el nombre cuando la parada no
  tiene título propio.
- **Accesibilidad**: el botón del trofeo se anuncia como «Clasificación», y la X
  de la pista como «Cerrar pista».
- **«Peliculas» → «Películas»**: es un dato de la temática en la base. Se
  corrige con una migración de datos, como en INT-142, aplicada en producción
  **con luz verde aparte**.

**Fuera de alcance:** el desglose del resumen por desafío es una funcionalidad
nueva, no un pulido. Va en su propia issue.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

- `app-player-path-home`: requisitos nuevos de cabecera sin cortes y botón de
  clasificación con nombre accesible.
- `app-game-screen`: requisitos nuevos de cabecera de partida, hoja de
  resultado sin cifras antes de contar, copy de la pista y botón de cerrar
  pista accesible.
- `app-world-map`: requisito nuevo de rótulos de pin dentro del mapa.
- `app-level-summary`: requisito nuevo de ánimo según la cercanía al mínimo.
- `app-login`: requisito nuevo de línea «Siguiente» sin repetición.

## Impact

- `app/lib/screens/camino_screen.dart`, `nivel_juego_screen.dart`,
  `resumen_nivel_screen.dart` y `login_screen.dart`.
- `app/lib/mapa/mapa_mundi.dart`.
- Tests de esas pantallas y del mapa.
- `backend/supabase/migrations/20261118130000_tilde_tematica_peliculas.sql` y
  `seed.sql`.
- La rama incluye también `20261118120000_titulo_parada_monumentos_del_mundo.sql`,
  la migración de INT-142, ya aplicada en producción. No es parte de este
  cambio: está para que el historial local coincida con el remoto y
  `db push` funcione. El fichero es idéntico al del PR de INT-142.
- No cambian las dependencias.
