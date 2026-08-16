## 1. Persistencia remota del apodo

- [x] 1.1 Crear `ProfileGateway` (patrón `AuthGateway`) con `updateNickname(String nombre)` sobre `Supabase.instance.client.from('profiles').update({'nombre': nombre}).eq('id', ...)`, usando el `id` de la sesión actual
- [x] 1.2 Crear `FakeProfileGateway` en `test/fakes/` (patrón `FakeAuthGateway`) con contador de llamadas y capacidad de simular fallo

## 2. Pantalla "Nombre de usuario"

- [x] 2.1 Crear `UsernameScreen` reproduciendo la estructura del diseño `[App] - Nombre de usuario.dc.html`: cabecera de marca, campo de apodo, contador `n/16`, texto de tranquilidad, chips de sugerencias y CTA "Empezar a jugar"
- [x] 2.2 Validación de longitud: CTA deshabilitado fuera del rango `[3, 16]` caracteres (tras `trim`), con indicación del mínimo cuando esté por debajo
- [x] 2.3 Botón de dado: rellena el campo con un apodo aleatorio de una lista fija embebida
- [x] 2.4 Al pulsar "Empezar a jugar": guardar en `UsernameStorage`, luego en `ProfileGateway.updateNickname`, y navegar a `TopicsMapPlaceholderScreen`; si falla el guardado remoto, mostrar error inline sin navegar y sin perder el apodo ya escrito
- [x] 2.5 Enlace secundario "¿Ya tienes una cuenta? Iniciar sesión": visible, sin `onTap`
- [x] 2.6 Sustituir `UsernamePlaceholderScreen` por `UsernameScreen` en `SplashScreen._navigateNext` y eliminar el placeholder

## 3. Tests

- [x] 3.1 Tests de validación: campo vacío, por debajo del mínimo, dentro de rango, tope del máximo (`maxLength` del `TextField`)
- [x] 3.2 Test de guardado correcto: pulsar "Empezar a jugar" guarda en `UsernameStorage` y en `ProfileGateway`, y navega a `TopicsMapPlaceholderScreen`
- [x] 3.3 Test de fallo remoto: `FakeProfileGateway` lanza error → se muestra el error, no navega, y el apodo sigue en el campo
- [x] 3.4 Test del botón de dado: tras pulsarlo, el campo tiene un valor no vacío
- [x] 3.5 Test del enlace secundario: está presente y no navega ni cambia estado al pulsarlo
- [x] 3.6 Actualizar `splash_screen_test.dart` para que la ruta post-splash sin apodo guardado sea `UsernameScreen` en vez de `UsernamePlaceholderScreen`
