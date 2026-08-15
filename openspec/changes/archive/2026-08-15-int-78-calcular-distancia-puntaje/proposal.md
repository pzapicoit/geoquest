## Why

El esquema del juego (INT-74) guarda `lat_adivinada`/`lng_adivinada` y las
columnas `distancia_km`/`puntos` en `respuestas_desafio`, pero nada calcula
esos dos últimos valores todavía: hoy tendría que rellenarlos el propio
cliente, que es exactamente el dato que no nos podemos fiar que envíe sin
manipular (haría trivial falsificar la puntuación). INT-78 cierra ese hueco:
calcula distancia y puntaje en el servidor y los persiste de forma fiable
cuando un jugador responde a un desafío.

## What Changes

- Nueva función SQL `calcular_distancia_km(lat1, lng1, lat2, lng2)`: distancia
  en kilómetros entre dos coordenadas usando la fórmula de Haversine (sin
  extensión PostGIS — D7 de INT-74 dejó las columnas como `double precision`
  planas justo para esto).
- Nueva función SQL `calcular_puntaje(distancia_km)`: puntaje 0-5000 con
  decaimiento lineal hasta 0 a partir de un umbral de distancia (constantes
  ajustables dentro de la función).
- Nueva RPC `responder_desafio(intento_id, desafio_id, lat_adivinada,
  lng_adivinada)`: valida que el intento pertenece al usuario autenticado,
  busca `lat_real`/`lng_real` del desafío (sin exponerlas nunca al cliente),
  calcula distancia y puntos, e inserta la fila en `respuestas_desafio`. Es
  el camino que usará la app al enviar la respuesta de un jugador a un
  desafío.
- Trigger `before insert` en `respuestas_desafio` que recalcula
  `distancia_km`/`puntos` siempre a partir de `lat_adivinada`/`lng_adivinada`
  y del desafío, ignorando cualquier valor que llegue en el `insert`. Esto
  hace que el guardado automático sea válido también si algo inserta
  directamente en la tabla en vez de pasar por la RPC (la policy de RLS de
  INT-77 ya permite ese insert directo, y hoy no habría nada evitando que el
  cliente mintiera sobre su propia distancia/puntaje).
- Casos límite verificados manualmente contra el proyecto Supabase enlazado:
  misma ubicación exacta (distancia 0, puntaje máximo) y extremos opuestos
  del globo (distancia máxima ~20000km, puntaje 0).

## Capabilities

### New Capabilities
- `challenge-scoring`: cálculo de distancia y puntaje al responder un
  desafío, y el mecanismo (RPC + trigger) que garantiza que esos valores
  están calculados por el servidor y no por el cliente.

### Modified Capabilities
_(ninguna — `game-data-model` no cambia sus requisitos: la RLS de
`respuestas_desafio` ya permitía el insert que la RPC usa internamente; solo
se le añade un trigger que no cambia qué se puede leer/escribir, solo qué
valores puede tener lo que se escribe)._

## Impact

- **Base de datos**: nueva migración con 2 funciones de cálculo, 1 función
  RPC y 1 trigger sobre `respuestas_desafio`. No cambia ninguna tabla.
- **App (Flutter)**: consumidor futuro de la RPC `responder_desafio` al
  enviar la respuesta de un jugador (la integración de la app no es parte de
  este ticket, solo la RPC que la expone).
- **INT-79** (cierre de `intento_nivel`): puede apoyarse en `puntaje_total`
  agregando los `puntos` que esta RPC ya deja guardados por desafío.
