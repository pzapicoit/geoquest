## ADDED Requirements

### Requirement: Fidelidad visual y de animación con el mock de referencia

La presentación del splash SHALL reproducir el diseño (fondo, tipografía y logo) y las animaciones de entrada definidas en su mock de referencia (`[App] - Splash.dc.html`, dirección "1a Mapa nocturno"), en vez de mostrarse como una composición estática sin animar.

#### Scenario: El splash aparece al abrir la app

- **WHEN** el jugador abre la app y se muestra el splash
- **THEN** el logo, el wordmark y la tagline entran con una animación (no aparecen de golpe), sobre el fondo oscuro con degradado y ruta punteada del mock de referencia

#### Scenario: El jugador tiene el sistema configurado para reducir movimiento

- **WHEN** el sistema operativo tiene activada la preferencia de accesibilidad "reducir movimiento"
- **THEN** el splash muestra el logo, el wordmark y la tagline directamente en su estado final, sin reproducir las animaciones de entrada ni los bucles decorativos
