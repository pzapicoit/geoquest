## 1. Backend — esquema

- [x] 1.1 Migración: `create type tipo_comodin as enum ('tiempo','pais','km1000','km500')`.
- [x] 1.2 Migración: `create table comodines_inventario (usuario_id uuid references profiles(id) on delete cascade, tipo tipo_comodin, cantidad integer not null default 0 check (cantidad >= 0), primary key (usuario_id, tipo))`, con RLS: `select`/`update` solo de la propia fila (mismo patrón que `profiles`), sin `insert`/`delete` directo por REST (solo vía RPC/trigger `security definer`).
- [x] 1.3 Migración: `alter table intentos_nivel add column comodin_usado tipo_comodin`.
- [x] 1.4 Migración: `alter table desafios add column pais text`.
- [x] 1.5 Actualizar el trigger `handle_new_user` (INT-75) para sembrar las 4 filas de `comodines_inventario` del perfil nuevo (`{tiempo:1, pais:1, km1000:1, km500:0}`).
- [x] 1.6 Migración: `create table comodines_concesiones_anuncio (usuario_id uuid, fecha date, cantidad integer not null default 0, primary key (usuario_id, fecha))` para el tope diario (D6 de design.md).

## 2. Backend — RPCs

- [x] 2.1 `mis_comodines()`: devuelve el inventario del jugador autenticado (4 filas o su forma agregada), para que la app pinte el pill y la pantalla Comodines.
- [x] 2.2 `usar_comodin(p_intento_id uuid, p_desafio_id uuid, p_tipo tipo_comodin)`: valida propiedad e intento abierto, valida disponibilidad de dato para `pais` (D4/D5 de design.md), decrementa inventario y marca `intentos_nivel.comodin_usado` de forma atómica, devuelve el payload según tipo (`extra_segundos` para `tiempo`; `pais` para `pais`; `lat`/`lng`/`radio_km` para `km1000`/`km500`). Corregido a `security definer` en `20260820091000_corrige_comodines_security_definer.sql` (con `security invoker` fallaba por RLS al escribir, detectado probando contra el remoto).
- [x] 2.3 `conceder_comodin_por_anuncio()`: comprueba el tope diario en `comodines_concesiones_anuncio`, concede 1 unidad de un tipo aleatorio uniforme si no se ha alcanzado, incrementa el contador del día. Mismo fix de `security definer` que 2.2.
- [x] 2.4 Verificado funcionalmente contra el proyecto remoto (sin Docker, no aplica pgTAP): sesión anónima real → `mis_comodines()` devuelve la semilla 1/1/1/0; `usar_comodin` con intento inexistente rechaza sin tocar inventario; `usar_comodin` con `pais` sobre un desafío real sin `pais` registrado rechaza con `pais_no_disponible` sin descontar; `usar_comodin` con `km1000` sobre un desafío real devuelve lat/lng reales y decrementa; un segundo uso en el mismo intento se rechaza con `comodin_ya_usado_en_este_intento`; `conceder_comodin_por_anuncio` concede 5 veces y rechaza la 6ª con `tope_diario_alcanzado`. `supabase db lint --linked` sin errores.

## 3. Panel — formulario de preguntas

- [x] 3.1 Añadir campo opcional `pais` al formulario de preguntas (`panel/src/lib/preguntaForm.ts`, `panel/src/pages/PreguntaForm.tsx`), mismo tratamiento que `pista` (INT-116): no bloquea guardar si está vacío.
- [x] 3.2 Tests Vitest del formulario: guardar con y sin `pais` (35/35 tests OK, `tsc --noEmit`/ESLint/Prettier limpios).

## 4. App — modelo y assets de comodines

- [x] 4.1 Copiados `Recursos/comodines/0..8.png` (original conservado) a `app/assets/comodines/` con nombres descriptivos (`generico`, `arte_tiempo/pais/km1000/km500`, `icono_tiempo/pais/km1000/km500`) y registrados en `pubspec.yaml`. Confirmados visualmente 1/2/7/8 (arte tiempo/país, icono "< 1000 km"/"< 500 km") antes de nombrarlos.
- [x] 4.2 `ComodinTipo` (enum con `aTexto`/`fromString`) y `ComodinesGateway`/`SupabaseComodinesGateway` en `app/lib/services/comodines_gateway.dart` (mismo patrón que `camino_gateway.dart`/`nivel_juego_gateway.dart`): `misComodines()`, `usarComodin()` (payload como clases selladas `ResultadoTiempo`/`ResultadoPais`/`ResultadoRadio`), `concederComodinPorAnuncio()`. Errores de Postgrest traducidos a `ComodinRechazadoException(MotivoRechazoComodin)` (enum tipado, no strings sueltos en la UI). Tests de las funciones puras de mapeo en `test/comodines_gateway_test.dart` (17 tests) y falso en `test/fakes/fake_comodines_gateway.dart`.

## 5. App — cronómetro

- [x] 5.1 Añadir `CuentaAtrasDeDesafio.extender(Duration)` en `app/lib/screens/cuenta_atras_de_desafio.dart`: adelanta `_fin`, suma la duración a `_total`/`_restante`, sin reiniciar el ticker si ya está corriendo. Sin efecto si el desafío ya se agotó o está parado (`_fin == null`).
- [x] 5.2 Tests unitarios de `extender` (4 nuevos, 24/24 en el archivo): aumenta restante y total sin reiniciar, retrasa de verdad el auto-envío, no hace nada si ya se agotó o si está parado.

## 6. App — bandeja de comodines en la pantalla de juego

- [x] 6.1 `BandejaComodines` (`app/lib/screens/bandeja_comodines.dart`, archivo propio como `MapaMundiController`/`CuentaAtrasDeDesafio`): pestaña plegada pegada al borde derecho (icono genérico + flecha), se despliega hacia la izquierda en una fila con los 4 iconos cuadrados y cierra al tocar la X o al tocar fuera (capa transparente a pantalla completa solo mientras está desplegada). Solo visible en la fase de adivinar (`!revelando && !_pistaVisible`), alineada un poco por encima del centro para no solaparse con los botones +/− del mapa (decisión propia, sin mockup de esta pantalla que consultar).
- [x] 6.2 Cada icono se deshabilita (atenuado, sin `onTap`) si no hay inventario de ese tipo o si `_comodinUsadoEnEsteIntento` (bandera local, D2) ya está activa. **Excepción documentada:** `pais` NO se puede deshabilitar de antemano por falta de dato — `desafios_para_jugar`/`iniciar_intento_parada` (backend ya implementado) nunca exponen `pais` al cliente antes de consumir el comodín, así que ese caso se resuelve como un rechazo normal de `usar_comodin` (`pais_no_disponible`) tras el toque, con un aviso, sin tocar inventario ni marca — ver comentario extenso en `bandeja_comodines.dart` y el reporte final de la tarea.
- [x] 6.3 `_NivelJuegoScreenState._usarComodin` llama a `ComodinesGateway.usarComodin` y aplica el efecto: `tiempo` → `CuentaAtrasDeDesafio.extender(Duration(seconds: extra_segundos))`; `pais` → toast con el país; `km1000`/`km500` → `MapaMundiController.mostrarRadio(...)` (grupo 7). Rechazos traducidos a mensajes específicos por `MotivoRechazoComodin`; el círculo de radio se limpia al entrar en el revelado (`_lanzarElRevelado`).
- [x] 6.4 10 tests de widget en `nivel_juego_screen_test.dart` (grupo "bandeja de comodines"): plegada por defecto, oculta con la pista abierta, se despliega con los 4 tipos, tocar fuera repliega, sin inventario no responde, tras usar uno el resto queda deshabilitado el resto del intento, tiempo extiende la cuenta atrás, país avisa con el nombre recibido, radio dibuja el círculo (`mapa-circulo-radio`), y un rechazo conocido (`pais_no_disponible`) avisa sin romper la pantalla ni marcar el intento como usado.

## 7. App — overlay de radio en el mapa

- [x] 7.1 `puntosDelCirculo` en `app/lib/mapa/circulo_radio.dart` (análogo a `interpolarGranCirculo` de `gran_circulo.dart`, pero con la fórmula de "destino esférico" rumbo+distancia para un círculo completo en vez de un arco entre dos puntos). `MapaMundiController` gana `centroRadio`/`radioKm` + `mostrarRadio(centro, radioKm)`/`limpiarRadio()`. `_PintorCirculoDeRadio` en `mapa_mundi.dart` proyecta con `camara.puntoDe` y usa `partirEnElAntimeridiano` para trocear si el círculo cruza el antimeridiano (solo traza el contorno sin relleno cuando queda partido en varios tramos, para no rellenar una forma sin sentido).
- [x] 7.2 Tests unitarios en `test/circulo_radio_test.dart` (6 tests: distancia real al centro con Haversine, cierre del contorno, ecuador, cerca de un polo, cerca del antimeridiano con longitudes normalizadas, radio mayor aleja los puntos) y 4 tests nuevos de `mostrarRadio`/`limpiarRadio` en `mapa_mundi_controller_test.dart`, mismo estilo que el resto de la aritmética de cámara (sin gestos).

## 8. App — Home y pantalla Comodines

- [x] 8.1 `_PildoraComodines` en `camino_screen.dart`: icono genérico + total sumado + "+", fondo/borde teal translúcido, junto al pill de puntos de `_BarraSuperior`; navega a `ComodinesScreen` reenviando `puntosTotales` ya cargado (mismo patrón que la navegación a `RankingScreen`). El total se recarga en `initState` y en `didPopNext` (por si se usó/ganó algún comodín fuera de esta pantalla).
- [x] 8.2 `ComodinesScreen` nueva (`app/lib/screens/comodines_screen.dart`): cabecera con atrás/título/subtítulo del total/badge de puntos, lista de 4 tarjetas anchas (arte real, cantidad, nombre, botón "?" con `SnackBar` de descripción) y botón fijo "Obtener más" → hoja inferior con 3 opciones. "Canjear puntos"/"Pack explorador" siempre avisan "próximamente" al tocar, sin acción real. "Ver un anuncio": dado que INT-117 (AdMob) no está integrada, se sigue literalmente el escenario "La vía de anuncio no está disponible todavía" de `comodines/spec.md` — el botón se muestra deshabilitado y el toque solo avisa "próximamente", **sin** llamar a `concederComodinPorAnuncio()` (para no conceder un comodín por un anuncio que nunca se vio). El flag `anuncioDisponible` (hoy `false`) documenta el punto exacto a cambiar cuando INT-117 aterrice; el gateway ya está listo y probado.
- [x] 8.3 10 tests de widget en `comodines_screen_test.dart` (tarjetas con cantidad, subtítulo con el total, badge de puntos, botón "?", error+reintentar, las 3 opciones de la hoja, botón atrás) y 2 tests nuevos en `camino_screen_test.dart` (el pill suma los 4 tipos, tocarlo navega a Comodines).

## 9. Cierre

- [x] 9.1 `flutter analyze` limpio, `dart format --set-exit-if-changed lib test` sin cambios, `flutter test` 371/371 verdes (verificado de forma independiente tras el trabajo del agente de los grupos 4/6/7/8).
- [x] 9.2 `supabase db lint --linked` sin errores (verificado al escribir el grupo 1/2, antes de que existiera contenido de los grupos 6-8 que lo pudiera afectar).
- [x] 9.3 ESLint/Prettier/`tsc --noEmit` limpios sobre el cambio de `panel/` (verificado al escribir el grupo 3).
- [x] 9.4 `.devplugin/architecture.md` actualizado: filas de `backend/`, `app/` y `panel/` con el resumen de INT-119 (esquema/RPCs, UI de la app, campo `pais` del panel), incluyendo la nota sobre `security definer` y la limitación conocida del comodín país (no se puede deshabilitar de antemano en el cliente).
