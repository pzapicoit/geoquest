## 1. Arranque al cerrar la pista

- [x] 1.1 Tests en rojo: con la pista abierta 10 s, la barra sigue llena y `marcarDesafioMostrado` no se ha llamado; al pulsar «Listo» arranca y se llama una vez; al cerrar con la X también; reabrir la pista no la para ni vuelve a llamar; el desafío siguiente espera a su propio cierre
- [x] 1.2 `_prepararCuentaAtras` (barra llena y quieta) en los puntos donde hoy se arranca, y `_arrancarCuentaAtras` en el primer cierre de la pista de cada desafío

## 2. Tope de lectura

- [x] 2.1 Tests: a los 20 s la pista se cierra sola y arranca la cuenta atrás; la barra del tope se ve en la tarjeta; reabrir la pista con el reloj en marcha no rearma el tope
- [x] 2.2 Timer de 20 s y barra fina bajo «Listo»; cancelación al cerrar, al avanzar y al salir

## 3. Cierre

- [x] 3.1 `flutter analyze`, `dart format` y `flutter test` en verde
- [ ] 3.2 Prueba en web: al pulsar «Listo» la barra está llena; dejando la pista abierta, se cierra sola a los 20 s
