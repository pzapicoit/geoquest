## 1. Backend: `cerrar_intento_nivel` enriquecido

- [x] 1.1 Nueva migración: `drop function cerrar_intento_nivel(uuid)` +
      `create function` que devuelve `jsonb` con `puntaje_total`,
      `superado`, `estrellas_obtenidas`, `puntaje_minimo_superar` y
      `mejor_puntaje_anterior` (NULL si no hay fila previa en
      `progreso_usuario_nivel` para ese usuario/nivel).
- [x] 1.2 Capturar `mejor_puntaje_anterior` con un `select` a
      `progreso_usuario_nivel` **antes** del `insert ... on conflict do
      update` existente, sin tocar el resto de la lógica de superación,
      estrellas, progreso o desbloqueo del camino (D1/D2 de `design.md`).
- [x] 1.3 `revoke`/`grant execute` de la función nueva a `authenticated`,
      como en las migraciones anteriores de esta función.
- [x] 1.4 `supabase db push` al proyecto remoto (sin stack local con
      Docker, per `architecture.md`) y comprobación a mano vía REST con un
      usuario anónimo real: `cerrar_intento_nivel` con un `intento_id`
      inexistente devuelve el mismo error de guarda de siempre, confirmando
      que el `grant` a `authenticated` quedó bien tras el `drop`+`create`.
      Los tres casos de resultado (con récord / sin récord / no superado)
      se ejercitan de punta a punta jugando la app en 9.2.

## 2. App: gateway y modelo del resultado

- [x] 2.1 En `nivel_juego_gateway.dart`, nuevo modelo inmutable
      `ResultadoIntento` con `puntajeTotal`, `superado`, `estrellas`,
      `puntajeMinimoSuperar` y `mejorPuntajeAnterior` (`int?`).
- [x] 2.2 Nuevo método `cerrarIntento(String intentoId)` en
      `NivelJuegoGateway` (abstracto) y en `SupabaseNivelJuegoGateway`,
      llamando a la RPC `cerrar_intento_nivel`.
- [x] 2.3 Función pura `mapearResultadoIntento(Map<String, dynamic>)`,
      reutilizando los helpers `_entero`/`_texto` existentes para el
      parseo, y probada sin red (`nivel_juego_gateway_test.dart`), con
      casos con y sin `mejor_puntaje_anterior`.
- [x] 2.4 Actualizar `FakeNivelJuegoGateway` (test/fakes) con
      `cerrarIntento`: contador de llamadas, `intentoId` recibido,
      resultado configurable, `throwOnNextCerrar` y `pausaAlCerrar` (mismo
      patrón que `iniciarIntento`/`responderDesafio`).

## 3. App: datos del nivel hacia la pantalla de juego

- [x] 3.1 `NivelJuegoScreen` acepta `nivelOrden` (int) y `tematicaNombre`
      (String), además del `nivelNombre` que ya recibe.
- [x] 3.2 `camino_screen._onTapParada` pasa `parada.orden` y
      `parada.tematicaNombre` al construir `NivelJuegoScreen`.

## 4. App: cerrar el intento desde "Ver resultados"

- [x] 4.1 En `_avanzarDesdeElRevelado`, cuando `revelado.esElUltimo`:
      llamar a `gateway.cerrarIntento(intento.intentoId)` en vez de
      `Navigator.pop`, con un estado `_cerrando` que deshabilite el botón
      mientras está en curso (mismo patrón que `_enviando` en
      `_confirmar`).
- [x] 4.2 Si `cerrarIntento` falla: avisar con `_avisar(...)`, volver a
      habilitar el botón y mantener el revelado tal cual, sin navegar.
- [x] 4.3 Si `cerrarIntento` resuelve: `Navigator.of(context)
      .pushReplacement(...)` a `ResumenNivelScreen` con el
      `ResultadoIntento`, `nivelId`, `nivelNombre`, `nivelOrden`,
      `tematicaNombre`, el total de desafíos del intento (
      `intento.desafios.length`) y el `gateway` (para que "Reintentar"
      pueda arrancar un intento nuevo).

## 5. App: pantalla de resumen — estructura y estado superado

- [x] 5.1 Nuevo archivo `lib/screens/resumen_nivel_screen.dart` con
      `ResumenNivelScreen` (`StatefulWidget`), paleta/tipografías propias
      (D7 de `design.md`) y el layout base de pantalla completa del
      mockup (degradados de fondo, sin barra de estado simulada).
- [x] 5.2 Cabecera común: pill "Nivel N · Zona", título y subtítulo según
      `superado` (mensaje de celebración vs. de ánimo).
- [x] 5.3 Fila de 3 huecos de estrella con los tamaños del mockup
      (78/104/78 px). Estado no superado: las 3 apagadas, sin animación.
- [x] 5.4 Estado superado: `Timer` encadenados que encienden una estrella
      cada 480 ms tras un retraso inicial de 420 ms, con el pop/halo del
      mockup; al terminar la última estrella, si `estrellas == 3`, disparo
      del confeti (D8/D9 de `design.md`). Cancelar todos los `Timer` en
      `dispose`.
- [x] 5.5 Confeti hecho a mano: 30 piezas con el generador
      pseudo-aleatorio determinista del mock (posición, tamaño, color,
      retraso, duración), animadas con `AnimatedBuilder`.
- [x] 5.6 Bloque de puntaje: "Puntos del intento" + `puntajeTotal`
      formateado con `formatearPuntaje` (reutilizar la función ya
      existente, no duplicarla).
- [x] 5.7 Aviso de récord: visible solo si `superado &&
      mejorPuntajeAnterior != null && puntajeTotal > mejorPuntajeAnterior`
      (D3 de `design.md`), con la diferencia formateada; entra con
      retraso tras las estrellas.
- [x] 5.8 Botón "Continuar" (`Navigator.of(context).pop()`) y acción
      "Repetir animación" que reinicia los `Timer` de estrellas/confeti
      sin llamar al servidor.

## 6. App: pantalla de resumen — estado no superado

- [x] 6.1 Tarjeta "cuánto faltó": `puntajeMinimoSuperar - puntajeTotal`,
      con el mínimo del nivel como referencia y una barra de progreso
      hacia ese mínimo (`min(100%, puntajeTotal / puntajeMinimoSuperar)`).
- [x] 6.2 Texto de ánimo bajo la barra, genérico (no atado a cifras de
      ejemplo — D10 de `design.md`).
- [x] 6.3 Botón "Reintentar": `Navigator.of(context).pushReplacement(...)`
      a un `NivelJuegoScreen` nuevo con el mismo `nivelId`/`nivelNombre`/
      `nivelOrden`/`tematicaNombre`/`gateway` (D5 de `design.md`).
- [x] 6.4 Enlace "Volver al camino": `Navigator.of(context).pop()`.

## 7. App: recarga del camino al volver de jugar

- [x] 7.1 `camino_screen` se suscribe a un `RouteObserver<PageRoute>`
      compartido (`lib/route_observer.dart`, registrado en
      `MaterialApp.navigatorObservers`) y recarga (`_futuro = _cargar()`)
      en `didPopNext()`, para que la recarga dispare al volver a ser la
      pantalla visible sea cual sea la cadena de `push`/`pushReplacement`
      por encima (incluido "Reintentar"), no solo al volver del primer
      `push` (D6 de `design.md`).

## 8. Tests

- [x] 8.1 `nivel_juego_gateway_test.dart`: casos de
      `mapearResultadoIntento` (con y sin `mejor_puntaje_anterior`, y de
      formato numérico como el resto de mapeadores del archivo).
- [x] 8.2 `nivel_juego_screen_test.dart`: "Ver resultados" en el último
      desafío llama a `cerrarIntento` con el `intentoId` correcto, navega
      al resumen al resolver, y si `cerrarIntento` lanza, avisa y
      mantiene el revelado sin navegar.
- [x] 8.3 Nuevo `resumen_nivel_screen_test.dart`: estado superado muestra
      estrellas/puntaje/mensaje y "Continuar" hace pop; estado no
      superado muestra "cuánto faltó" y "Reintentar"/"Volver al camino";
      récord visible solo cuando corresponde (los 3 escenarios del D3);
      confeti solo con 3 estrellas.
- [x] 8.4 `camino_screen_test.dart`: volver de `NivelJuegoScreen` dispara
      una recarga del camino (contador de llamadas al gateway falso antes
      y después de simular el `pop`).
- [x] 8.5 `camino_screen_test.dart`: la cadena completa
      `NivelJuegoScreen → Resumen (no superado) → Reintentar →
      NivelJuegoScreen → Resumen (superado) → Continuar` recarga el camino
      al volver — regresión encontrada en `/opsx-verify` (D6): un `.then()`
      sobre el `push` original se resolvía en el primer `pushReplacement`
      y nunca recargaba tras un "Reintentar" que sí superaba el nivel.

## 9. Verificación local

- [x] 9.1 `flutter analyze` y `flutter test` en `app/` sin fallos.
- [ ] 9.2 Ejecutar la app contra Supabase local, jugar un nivel completo
      hasta el resumen en sus dos variantes (forzando un resultado por
      debajo y por encima del mínimo) y comprobar visualmente contra el
      mockup de Claude Design.
