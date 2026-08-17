## 1. Dependencias

- [x] 1.1 Añadir `video_player` a `app/pubspec.yaml` y correr `flutter pub get`.

## 2. Gateway y modelos

- [x] 2.1 Crear `app/lib/services/nivel_juego_gateway.dart` con
      `DesafioJuego`, `IntentoNivel`, la clase abstracta
      `NivelJuegoGateway` y `SupabaseNivelJuegoGateway` que llama a
      `iniciar_intento_nivel` vía `_client.rpc(...)` y mapea la respuesta
      jsonb a los modelos.
- [x] 2.2 Tests unitarios del mapeo (jsonb de la RPC → `IntentoNivel`
      con su lista de `DesafioJuego`) y de la propagación del error
      cuando la RPC falla, con datos de ejemplo por cada `tipo`
      (`imagen`, `video`, `pregunta_texto`). Propagación del error
      cubierta a nivel de pantalla (3.6) vía `FakeNivelJuegoGateway`,
      igual que `CaminoGateway`/`CaminoScreen`.

## 3. Pantalla de juego

- [x] 3.1 Crear `app/lib/screens/nivel_juego_screen.dart`
      (`NivelJuegoScreen`) que recibe `nivelId` (+ `gateway` opcional
      para tests, patrón de `CaminoScreen`).
- [x] 3.2 Estado de carga mientras se llama a `iniciarIntento`, y estado
      de error con botón "Reintentar" si falla (D6 de `design.md`).
- [x] 3.3 Widget de toast que decide qué contenido pintar según
      `tipo` del desafío actual: imagen (`Image.network`), vídeo
      (`video_player`, autoplay + loop + `setVolume(0)` según D5) o
      texto de la pregunta en tamaño grande.
- [x] 3.4 Cabecera con progreso "Desafío X de N" (índice local + 1 /
      total de desafíos) y puntaje acumulado del intento fijo en 0
      (D3/D4 de `design.md`).
- [x] 3.5 Botón "Listo, voy a adivinar" que oculta el toast y revela el
      estado de mapa a pantalla completa (stub interno de la propia
      pantalla, ver D1 de `design.md`).
- [x] 3.6 Tests de widget: arranque muestra loading → contenido correcto
      por cada `tipo`; error de la RPC muestra el estado de error;
      cerrar el toast revela el stub de mapa; cálculo de "Desafío X de
      N" con distintos tamaños de lista.

## 4. Integración con el camino

- [x] 4.1 Actualizar `_onTapParada` en `app/lib/screens/camino_screen.dart`
      para navegar a `NivelJuegoScreen(nivelId: parada.nivelId)` en vez
      de `NivelJuegoPlaceholderScreen`.
- [x] 4.2 Eliminar `app/lib/screens/nivel_juego_placeholder_screen.dart`
      y cualquier referencia/test que quede de él.
- [x] 4.3 Ejecutar la suite completa de tests de `app/` y `flutter
      analyze` para confirmar que no queda nada roto por el cambio de
      navegación.

## 5. Fixes de la revisión adversarial

- [x] 5.1 `desafios[_indice]` crasheaba (`RangeError`) si la RPC
      devuelve `desafios: []` (nivel sin desafíos activos asignados).
      `NivelJuegoScreen` ahora comprueba `desafios.isEmpty` y muestra
      `_ErrorIntento` con mensaje específico antes de indexar.
- [x] 5.2 Un fallo de `VideoPlayerController.initialize()` (URL rota, o
      ausencia del plugin de plataforma en tests) se tragaba en
      silencio y dejaba `VideoPlayer` renderizando un controller sin
      inicializar (pantalla en negro sin explicación). `_PistaVideo`
      ahora resuelve a `Future<bool>` y muestra un aviso
      (`nivel-juego-video-error`) cuando la inicialización falla.
