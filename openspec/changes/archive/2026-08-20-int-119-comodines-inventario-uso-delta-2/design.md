## Context

El comodín de radio (`km1000`/`km500`) dibuja un círculo de acierto sobre el mapa (delta-1), pero no toca el encuadre de la cámara: si el jugador está muy alejado o desplazado, el círculo puede quedar diminuto o fuera de pantalla. `MapaMundiController.camaraPara(Iterable<Coordenada>, {margenes})` ya existe (usado por el encuadre del revelado) y encaja para esto.

## Goals / Non-Goals

**Goals:**
- Al consumir un comodín de radio, la cámara se anima hacia un encuadre que deja el círculo entero visible.
- `desafios.pais` relleno para todo el contenido existente salvo el caso sin país real (Titanic).
- Los dos defectos visuales del revelado corregidos.

**Non-Goals:**
- No se resuelve en este delta la idea de colorear el país sobre el mapa en vez de un círculo (comodín país) — el mapa no tiene ningún dataset de fronteras por país (es solo costa/relleno, ver architecture.md), así que eso exigiría añadir un dataset nuevo y extender el pintor; queda como decisión aparte, pendiente de que Pablo confirme si quiere ese alcance.

## Decisions

**D1 — Nueva animación de cámara dedicada (`_zoomComodin`) en `_NivelJuegoScreenState`, no en `MapaMundiController`.** Mismo patrón que `_acercamiento` de `_MapaMundiState` (doble toque, INT-114): un `AnimationController` corto (350ms) interpola entre la cámara actual y la que calcula `camaraPara(puntosDelCirculo(centro, radioKm), margenes: EdgeInsets.all(56))`. Vive en la pantalla de juego (quien decide CUÁNDO acercar) y no en el controller (que solo sabe posicionar), igual que la cámara del revelado.

**D2 — Se para la animación del comodín si el jugador confirma antes de que acabe.** `_lanzarElRevelado()` llama a `_zoomComodin.stop()` antes de tomar el control de la cámara: si no, las dos animaciones (zoom del comodín y coreografía del revelado) escribirían `aplicarCamara` en el mismo frame.

**D3 — El backfill de país se hizo con conocimiento geográfico directo, no con una llamada a un proveedor de IA externo.** Los 135 desafíos ya traían `nombre`/`nombre_lugar`/coordenadas suficientes para determinar el país sin ambigüedad razonable (verificado cruzando coordenadas, no solo el nombre — p. ej. "Museo de Antioquía" tiene coordenadas de Antakya, Turquía, no de Medellín). Evita construir una integración nueva con OpenAI (Edge Function, secretos, coste) para un backfill puntual de 134 filas.

**D4 — Miniatura de la pista: fondo oscuro plano en vez de degradado claro.** `Colors.white.withValues(alpha: 0.06)`, mismo tono que otros paneles sutiles sobre fondo oscuro ya usados en la app (p. ej. la bandeja de comodines antes del rediseño).

**D5 — Puntaje del revelado: el máximo pasa a su propia línea.** Mismo `formatearPuntaje` (separador de millares con punto, convención española) — no se cambia el separador porque se usa en toda la app; se cambia el layout para que el número grande no comparta línea con el "/ máximo", evitando la lectura como decimal.

## Risks / Trade-offs

- **[Riesgo] El backfill de país es una operación de datos manual, no repetible automáticamente para contenido futuro.** → Mitigación: el formulario de preguntas del panel ya pide `pais` desde la historia original; cualquier pregunta nueva lo pide de entrada. El backfill solo cubría la deuda del contenido creado antes de esa historia.
- **[Riesgo] "Titanic" se queda sin país real de forma permanente.** → Aceptado: no hay ningún país aplicable (naufragio en aguas internacionales), es la respuesta correcta, no una laguna a rellenar.

## Migration Plan

1. Backfill de datos vía REST con la clave de servicio (sin migración de esquema).
2. App: nueva animación de cámara + ajustes visuales, sin cambios de datos.

## Open Questions

- ¿Se aborda en un delta futuro colorear el país real sobre el mapa (comodín país) en vez del toast actual? Requiere un dataset de fronteras por país nuevo y extender el pintor del mapa — pendiente de que Pablo confirme si quiere ese alcance antes de diseñarlo.
