# app-splash Specification

## Purpose
TBD - created by archiving change int-88-app-splash. Update Purpose after archive.

## Requirements

### Requirement: Branding visible durante la carga
La pantalla inicial de la app SHALL mostrar el logo/branding de GeoQuest mientras se resuelve la sesión del jugador, sin dejar ningún instante con una pantalla en blanco o solo un indicador de carga genérico.

#### Scenario: La app arranca
- **WHEN** el jugador abre la app
- **THEN** la primera pantalla visible muestra el logo de GeoQuest mientras se resuelve la sesión

### Requirement: Crear sesión anónima si no existe
Si el dispositivo no tiene una sesión guardada, el splash SHALL crear una sesión anónima automáticamente contra Supabase Auth, sin requerir ninguna acción del jugador.

#### Scenario: Primer arranque en un dispositivo nuevo
- **WHEN** el jugador abre la app por primera vez y no hay sesión persistida en el dispositivo
- **THEN** el splash crea una sesión anónima en segundo plano sin mostrar ningún formulario ni pedir datos al jugador

### Requirement: Recuperar sesión existente sin crear una nueva
Si el dispositivo ya tiene una sesión guardada, el splash SHALL recuperarla directamente y NO SHALL crear una sesión anónima adicional.

#### Scenario: Segundo arranque con sesión persistida
- **WHEN** el jugador abre la app y el dispositivo ya tiene una sesión (anónima o vinculada) guardada
- **THEN** el splash reutiliza esa sesión y no se crea ninguna sesión nueva

### Requirement: Reintento cuando falla la resolución de la sesión
Si crear o recuperar la sesión falla (por ejemplo, sin conectividad), el splash SHALL mostrar un estado de error con el motivo y una acción para reintentar, en vez de navegar a otra pantalla.

#### Scenario: Falla la creación de la sesión anónima
- **WHEN** la llamada a Supabase Auth para crear o recuperar la sesión falla
- **THEN** el splash muestra el motivo del error y un botón "Reintentar" que vuelve a intentar la resolución de la sesión

### Requirement: Enrutamiento según nombre de usuario guardado
Una vez resuelta la sesión con éxito, el splash SHALL navegar a la pantalla "Nombre de usuario" si el dispositivo no tiene un nombre de usuario guardado todavía, o a la pantalla de bienvenida de regreso (capability `app-login`) si ya lo tiene.

#### Scenario: Primera vez, sin nombre de usuario guardado
- **WHEN** la sesión se resuelve con éxito y no hay nombre de usuario guardado en el dispositivo
- **THEN** la app navega a la pantalla "Nombre de usuario"

#### Scenario: Ya tiene nombre de usuario guardado
- **WHEN** la sesión se resuelve con éxito y ya existe un nombre de usuario guardado en el dispositivo
- **THEN** la app navega a la pantalla de bienvenida de regreso
- **AND** no navega directamente al Mapa de temáticas sin mostrar esa pantalla intermedia

### Requirement: Tiempo mínimo de splash
El splash SHALL permanecer visible al menos un tiempo mínimo razonable antes de navegar a la siguiente pantalla, incluso si la sesión se resuelve al instante, para evitar un parpadeo.

#### Scenario: La sesión resuelve casi al instante
- **WHEN** la sesión se resuelve con éxito en menos tiempo que el mínimo definido para el splash
- **THEN** la app espera hasta cumplir ese tiempo mínimo antes de navegar a la siguiente pantalla

### Requirement: Fidelidad visual y de animación con el mock de referencia

La presentación del splash SHALL reproducir el diseño (fondo, tipografía y logo) y las animaciones de entrada definidas en su mock de referencia (`[App] - Splash.dc.html`, dirección "1a Mapa nocturno"), en vez de mostrarse como una composición estática sin animar.

#### Scenario: El splash aparece al abrir la app

- **WHEN** el jugador abre la app y se muestra el splash
- **THEN** el logo, el wordmark y la tagline entran con una animación (no aparecen de golpe), sobre el fondo oscuro con degradado y ruta punteada del mock de referencia

#### Scenario: El jugador tiene el sistema configurado para reducir movimiento

- **WHEN** el sistema operativo tiene activada la preferencia de accesibilidad "reducir movimiento"
- **THEN** el splash muestra el logo, el wordmark y la tagline directamente en su estado final, sin reproducir las animaciones de entrada ni los bucles decorativos

### Requirement: Icono de la app en el launcher del dispositivo
La app instalada SHALL mostrar en el launcher/home screen del sistema operativo (iOS y Android) un icono acorde al branding de GeoQuest, sustituyendo el icono por defecto de Flutter.

#### Scenario: App instalada en Android
- **WHEN** la app se instala en un dispositivo Android
- **THEN** el icono que aparece en el launcher es el icono de marca de GeoQuest, no el icono por defecto de Flutter

#### Scenario: App instalada en iOS
- **WHEN** la app se instala en un dispositivo iOS
- **THEN** el icono que aparece en la pantalla de inicio es el icono de marca de GeoQuest, no el icono por defecto de Flutter
