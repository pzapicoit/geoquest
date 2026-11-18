## 1. Insignias con datos reales

- [x] 1.1 Tests de widget en rojo en `username_screen_test.dart`: con un `FakeCaminoGateway` de 8 paradas y 6 temáticas se ven «8 NIVELES» y «6 TEMÁTICAS» y no «RÉCORD»; singular con 1 parada; sin insignias si `fetchCamino` falla, y la pantalla sigue permitiendo entrar
- [x] 1.2 `UsernameScreen` recibe `CaminoGateway?`, lee el camino en `initState` y pinta las insignias con el hueco reservado mientras carga o si falla
- [x] 1.3 `LoginScreen` reenvía su `CaminoGateway` a `UsernameScreen`

## 2. Consejo de carga real

- [x] 2.1 Test: ningún consejo de `consejosDeCarga` menciona metros ni acercarse; con un `Random` fijo, el splash muestra el consejo esperado
- [x] 2.2 `consejosDeCarga` con 4-5 consejos de mecánica real y `Random` inyectable en `SplashScreen`

## 3. Cierre

- [x] 3.1 `flutter analyze`, `dart format` y `flutter test` en verde
- [x] 3.2 Prueba en web con Chrome DevTools: insignias reales en la pantalla de apodo y consejo correcto en el splash
  - Hecha el 2026-11-18 con `flutter run -d web-server` y el Chrome DevTools de ECC, en un contexto de navegador limpio (jugador nuevo, 390×844). La pantalla de apodo muestra «8 NIVELES» y «6 TEMÁTICAS» en una línea, leídos de producción (8 paradas, 6 temáticas). Durante la carga, el splash mostró «El mapa no tiene nombres: …», uno de los consejos nuevos, y ya no el de los 30 m.
