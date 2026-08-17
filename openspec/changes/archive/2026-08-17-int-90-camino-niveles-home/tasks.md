## 1. Modelos y gateway

- [x] 1.1 Definir `ParadaCamino` (modelo inmutable): `caminoId`, `orden`,
      `nivelId`, `nivelNombre`, `tematicaId`, `tematicaNombre`,
      `superado`, `estrellasObtenidas`, `estrellasRequeridas`,
      `estrellasAcumuladasUsuario`, `desbloqueado`, `esActual`,
      `imagenPortadaUrl` — mapeado desde una fila de `camino_jugador`
      combinada con la portada de su temática.
- [x] 1.2 Definir `ParadaFrontera` (modelo): `tematicaAnteriorNombre`,
      `tematicaSiguienteNombre`, `desbloqueada`, `estrellasFaltantes`.
- [x] 1.3 Definir `CaminoJugador` (modelo agregado): lista ordenada de
      paradas/fronteras ya intercaladas (ver 1.5) + `puntosTotales`.
- [x] 1.4 Crear `CaminoGateway` (abstracto) en
      `app/lib/services/camino_gateway.dart` con
      `Future<CaminoJugador> fetchCamino()`.
- [x] 1.5 Implementar `SupabaseCaminoGateway`: `Future.wait` de (a)
      `camino_jugador` ordenado por `orden`, (b) `tematicas` filtrado
      por los `tematica_id` distintos del resultado anterior
      (`select('id, imagen_portada')`), resolviendo cada
      `imagen_portada` con
      `storage.from('challenge-media').getPublicUrl(...)`, y (c) suma
      de `puntos` sobre `respuestas_desafio.select('puntos')` (la RLS ya
      restringe a las filas propias del usuario). Combina (a)+(b) y
      calcula la lista final intercalando una
      `ParadaFrontera` entre cada par de posiciones consecutivas con
      `tematica_id` distinto (estrellas faltantes = `max(1,
      estrellasRequeridas - estrellasAcumuladasUsuario)` de la posición
      siguiente).
- [x] 1.6 Crear `FakeCaminoGateway` en `app/test/fakes/` para tests de
      pantalla sin red.
- [x] 1.7 Tests unitarios de `SupabaseCaminoGateway`/la función de
      combinación: intercalado de frontera (bloqueada, desbloqueada, sin
      cambio de temática), suma de puntos con y sin respuestas, y
      cálculo de estrellas faltantes con el mínimo de 1.

## 2. Pantalla Home (camino vertical)

- [x] 2.1 Crear `CaminoScreen` (`app/lib/screens/camino_screen.dart`)
      que recibe/inyecta un `CaminoGateway`, carga el camino al iniciar
      y maneja estados de carga/error.
- [x] 2.2 Barra superior fija: avatar/acceso a perfil (stub con
      SnackBar "Perfil — pendiente"), nombre de usuario (desde el
      servicio/almacenamiento ya existente), label de progreso ("Nivel
      X de N · Y/Z ★") y píldora de puntos totales.
- [x] 2.3 Widget de parada normal: imagen de portada de la temática,
      número de nivel, nombre de temática, estrellas (0-3),
      texto meta según estado (bloqueada/actual/superada), candado si
      bloqueada, color de acento por `tematicaId`.
- [x] 2.4 Widget de parada frontera: candado + mensaje de estrellas
      faltantes cuando está bloqueada; estado neutro/pasado cuando está
      desbloqueada.
- [x] 2.5 Construir la lista (paradas + fronteras) en un `ListView`
      invertido (`reverse: true`) con alturas fijas conocidas, riel de
      progreso a la izquierda resaltado desde la posición actual hacia
      abajo.
- [x] 2.6 Auto-scroll al montar: calcular el offset de la parada
      `esActual` (o el final del camino si no hay ninguna) y
      posicionar el `ScrollController` sin animación visible de salto
      brusco.
- [x] 2.7 Manejo de toques: parada bloqueada y frontera no navegan;
      parada desbloqueada (actual o superada) navega a un stub de
      pantalla de juego con el `nivelId`/nombre de temática, a la
      espera de INT-91.

## 3. Integración y limpieza

- [x] 3.1 Cambiar el destino post-splash de
      `TopicsMapPlaceholderScreen` a `CaminoScreen` en
      `app/lib/screens/splash_screen.dart`/`app/lib/main.dart`.
- [x] 3.2 Eliminar `app/lib/screens/topics_map_placeholder_screen.dart`
      y sus referencias.
- [x] 3.3 Tests de widget de `CaminoScreen` con `FakeCaminoGateway`:
      estados superado/actual/bloqueado se renderizan distinto, la
      frontera bloqueada muestra el mensaje de estrellas faltantes, el
      toque en parada bloqueada no dispara navegación, el toque en
      parada desbloqueada sí.
- [x] 3.4 Verificar manualmente en el simulador/dispositivo: carga con
      progreso parcial, auto-centrado en la parada actual, y que el
      splash ya no lleva al placeholder.
