## Why

El jugador no tiene ninguna pantalla real tras elegir su nombre de usuario:
el splash navega a un placeholder (`TopicsMapPlaceholderScreen`) sin
contenido. INT-89, INT-96 e INT-98 ya dejaron listos el nombre de usuario,
la sesión y la vista `camino_jugador` (progreso + desbloqueo recalculado);
falta la pantalla Home que consuma ese progreso y le dé al jugador un
camino navegable con sus paradas.

## What Changes

- Nueva pantalla Home (`CaminoScreen`) que sustituye a
  `TopicsMapPlaceholderScreen` como destino del splash cuando ya existe
  nombre de usuario guardado.
- Barra superior fija con avatar/acceso a perfil, nombre de usuario, label
  de progreso ("Nivel X de N · Y/Z ★") y puntos totales acumulados.
- Camino vertical con scroll, una parada por posición de `camino_jugador`,
  con estados visuales `superado` (color + estrellas), `actual`
  (destacado, con foco de auto-scroll al montar) y `bloqueado` (gris,
  sin estrellas, no interactivo).
- Parada especial "frontera" entre el último nivel de una temática y el
  primero de la siguiente, con candado y mensaje de estrellas que faltan
  cuando está bloqueada.
- Ambientación de fondo que varía por temática, usando la imagen de
  portada de cada temática (`tematicas.imagen_portada`) como arte de cada
  parada — ya es de lectura pública y ya se declara en su spec como
  pensada para "mostrarse como título del mundo en el mapa del jugador".
- Toque sobre una parada desbloqueada (superada o actual) navega a la
  pantalla de juego de ese nivel (navegación stub hasta que exista esa
  pantalla — INT-91 la implementará).
- Nuevo gateway Supabase para leer `camino_jugador`, resolver la URL
  pública de portada por temática y sumar los puntos totales del jugador
  a partir de `respuestas_desafio`.

## Capabilities

### New Capabilities
- `app-player-path-home`: pantalla Home del jugador (camino vertical con
  progreso, desbloqueos, frontera entre temáticas y navegación a un
  nivel), y el gateway de app que la alimenta desde Supabase.

### Modified Capabilities
(ninguna — no cambia el comportamiento de `camino_jugador` ni de ninguna
spec de backend/panel ya archivada; esta pantalla solo consume datos ya
expuestos)

## Impact

- **Código nuevo**: `app/lib/screens/camino_screen.dart` (+ widgets de
  parada/frontera), `app/lib/services/camino_gateway.dart`.
- **Código modificado**: `app/lib/main.dart` o el splash
  (`app/lib/screens/splash_screen.dart`) para navegar a `CaminoScreen` en
  vez de al placeholder; se elimina
  `app/lib/screens/topics_map_placeholder_screen.dart`.
- **Dependencias externas**: ninguna nueva — usa `supabase_flutter` ya
  presente (`.storage.from('challenge-media').getPublicUrl(...)` y
  `.from('camino_jugador')`/`.from('tematicas')`/`.from('respuestas_desafio')`).
- **Backend**: sin cambios. Se apoya en la vista `camino_jugador`
  (INT-96/INT-98) y en `tematicas`/`respuestas_desafio`, ya legibles por
  cualquier usuario autenticado (incluida sesión anónima) según
  `game-data-model`.
