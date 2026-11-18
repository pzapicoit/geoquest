## Context

`UsernameScreen` no recibe ningún gateway de datos de juego: solo almacenamiento,
perfil, sesión y roster. `LoginScreen`, que la construye, ya tiene un
`CaminoGateway`, que usa la bienvenida. Cuando se muestra la pantalla de apodo ya
existe una sesión anónima, creada por el splash, así que `camino_jugador` es
legible.

## Goals / Non-Goals

**Goals:**
- Que ninguna cifra de la entrada sea inventada.
- Que el consejo de carga explique el juego de verdad.

**Non-Goals:**
- Récord global en la entrada. `app-login` lo excluye expresamente, y añadirlo
  pediría leer la clasificación antes de que el jugador tenga perfil.
- Quitar la fila «Próximamente». Se mantiene por fidelidad al mock y porque es
  honesta.

## Decisions

**D1. Las insignias salen de una sola lectura de `CaminoGateway`.**
`UsernameScreen` recibe un `CaminoGateway?` opcional. Si llega `null`, construye
`SupabaseCaminoGateway`, el mismo patrón que el resto de gateways de la pantalla.
Lanza `fetchCamino()` una vez en `initState`. «Niveles» es `entradas.length`;
«temáticas» es el número de `tematicaId` distintos.
- *Alternativa:* «N NIVELES» + «RÉCORD» real desde la clasificación global. Se
  descarta por coherencia con `app-login` y por no hacer dos lecturas.

**D2. Hueco reservado mientras carga.**
Mientras no hay datos, o si falla la lectura, se pinta un `SizedBox` con la
altura de una insignia en vez de la fila. Así el título y el formulario no saltan
cuando llegan las cifras. Un fallo no se reporta al jugador: las insignias son
decorativas y no deben bloquear la entrada.

**D3. Consejos en una lista pública y elección inyectable.**
`consejosDeCarga` es una `List<String>` pública, para que el test pueda comprobar
la lista entera. El splash elige uno en `initState` con un `Random` inyectable
(parámetro opcional del widget), y así el test de widget es determinista.

## Risks / Trade-offs

- [Una lectura de red más en la entrada] → Es la misma vista que ya lee la
  bienvenida y no bloquea nada: las insignias aparecen cuando llegan.
- [Las cifras cambian al editar el camino desde el panel] → Es lo deseado: dejan
  de estar desfasadas.
