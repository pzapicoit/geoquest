## 1. Zoom sobre la zona del comodín de radio

- [x] 1.1 `_NivelJuegoScreenState`: nuevo `AnimationController _zoomComodin` (350ms) + campos `_camaraAntesDelZoomComodin`/`_camaraDelZoomComodin`, dispuesto en `dispose()`.
- [x] 1.2 `_aplicarEfectoComodin` (caso `ResultadoRadio`): tras `mostrarRadio`, calcula el encuadre con `_mapa.camaraPara(puntosDelCirculo(centro, radioKm), margenes: EdgeInsets.all(56))` y lanza la animación.
- [x] 1.3 `_lanzarElRevelado()` para la animación del comodín (`_zoomComodin.stop()`) antes de tomar el control de la cámara, para que no compitan.
- [x] 1.4 Verificado con el test existente "usar un comodín de radio dibuja el círculo en el mapa" (usa `_asentar`, 600ms > los 350ms de la animación) — sin timers pendientes, 367/367 tests en verde.

## 2. Backfill de país en el contenido existente

- [x] 2.1 Determinados los 134 países (de 135 desafíos) a partir de `nombre`/`nombre_lugar`/coordenadas reales, verificando cruces de coordenadas en casos ambiguos (p. ej. "Museo de Antioquía" → Turquía, no Colombia, por sus coordenadas). "Titanic" se deja sin país (naufragio en aguas internacionales, no aplica ninguno).
- [x] 2.2 Aplicado vía REST con la clave de servicio (`PATCH` por fila, sin migración de esquema). Verificado: 134/135 con país, solo Titanic sin él.
- [x] 2.3 Verificado end-to-end: `usar_comodin` con `pais` sobre un desafío real ahora devuelve un país real (antes siempre rechazaba con `pais_no_disponible` por falta de contenido).

## 3. Fixes visuales del revelado (ajenos a comodines, encontrados en la misma sesión)

- [x] 3.1 `_MiniaturaDeLaPista`: fondo oscuro plano en vez del degradado claro que se veía como borde blanco.
- [x] 3.2 Bloque de puntaje del revelado: "/ máximo" pasa a su propia línea debajo del número grande, en vez de compartir línea con él.

## 4. Cierre

- [x] 4.1 `flutter analyze` limpio, `dart format --set-exit-if-changed` sin cambios.
- [x] 4.2 `flutter test` — 367/367 en verde.
- [x] 4.3 `.devplugin/architecture.md` actualizado (filas `backend/` y `app/`).
- [ ] 4.4 Sincronizar spec (`app-game-screen`) al archivar.
