## Context

INT-116 añadió `nombre` al toast de pista (`_TarjetaDePista`, junto a
`objetivo_global`) y dejó `nombre_lugar` solo en la tarjeta de revelado.
Probado en local, revela demasiado: para temáticas donde adivinar depende
de reconocer el sujeto (persona, película, monumento) a partir de la
imagen/vídeo, decir su nombre en la propia pista anula el desafío.

`_Revelado.desafio` (línea 91 de `nivel_juego_screen.dart`) ya guarda el
`DesafioJuego` completo del desafío respondido — incluido `nombre` — para
la miniatura de la pista (`_MiniaturaDeLaPista`). No hace falta ningún dato
nuevo del servidor: solo mover qué widget pinta `nombre` y en qué momento
del flujo.

## Goals / Non-Goals

**Goals:**
- El toast de pista (fase de adivinar) no revela `nombre` del desafío.
- La tarjeta de revelado (tras confirmar) muestra `nombre` junto a
  `nombre_lugar`.

**Non-Goals:**
- No cambia `objetivo_global` en el toast (sigue mostrándose: no revela
  nada específico del desafío).
- No cambia ningún contrato de backend (`iniciar_intento_parada`,
  `responder_desafio` no se tocan).
- No cambia el panel ni el esquema.

## Decisions

### D1: `nombre` se mueve de `_TarjetaDePista` a `_LugarRevelado`, sin tocar el backend

`_LugarRevelado` ya recibe `revelado` (tipo `_Revelado`), que ya expone
`revelado.desafio.nombre`. Basta con pintarlo ahí y quitar el bloque
equivalente de `_TarjetaDePista`. Se descarta cualquier cambio de RPC
porque el dato ya viaja al cliente desde `iniciar_intento_parada` y
sobrevive en memoria hasta el revelado.

## Risks / Trade-offs

- [Trade-off] `objetivo_global` se sigue mostrando en el toast sin
  `nombre`: para temáticas como "Banderas" (`objetivo_global` = "La
  capital de este país es..."), el jugador ve la instrucción pero no un
  nombre — comportamiento ya así de intencionado, sin cambio aquí.

## Migration Plan

Cambio de un solo commit en la app, sin migración de datos ni de esquema.
