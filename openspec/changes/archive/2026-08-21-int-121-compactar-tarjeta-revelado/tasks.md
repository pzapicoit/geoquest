## 1. Poda de la hoja de revelado

- [x] 1.1 Quitar de `_HojaDeRevelado` el `Align`/`TextButton` de "Repetir
      animación" (`nivel-juego-repetir`) y el campo `onRepetir`, y quitar el
      argumento `onRepetir: _lanzarElRevelado` de la llamada al widget (D1 de
      `design.md`).
- [x] 1.2 Ajustar el comentario de `_lanzarElRevelado`: ya no se "relanza"
      desde la UI, solo se lanza al confirmar y al agotarse el tiempo (D1).
- [x] 1.3 Quitar de `_TarjetaDePuntos` el `Text` de
      `nivel-juego-puntos-maximos` y su `SizedBox`, el parámetro `maximo` y su
      comentario de "debajo del número grande"; actualizar las dos llamadas
      (con y sin distancia) para no pasarlo (D2).
- [x] 1.4 Quitar de `_LugarRevelado` el `Text` de
      `nivel-juego-coordenadas-reales` y el `SizedBox` de 3 px que lo
      separaba, dejando `formatearCoordenadas` intacta (D4).
- [x] 1.5 Convertir `_DesgloseDePuntaje` de `Column` a `Wrap` con precisión,
      separador "·" y bonus en la misma línea, manteniendo keys, copy,
      colores y la regla de no pintar bonus cuando es 0, y comentando por qué
      `Wrap` y no `Row` (D3).

## 2. Encuadre del revelado

- [x] 2.1 Medir la altura real de la hoja en el caso más alto (con pin, con
      desglose) a 390×844, antes y después de la poda: **465 px → 373 px**.
      La franja de hoy (0.48 = 405 px) se quedaba corta, no larga (D5).
- [x] 2.2 Cambiar el margen inferior de `_margenesDelRevelado` a
      `alto * 0.46 + MediaQuery.viewPaddingOf(context).bottom`, con el
      comentario de dónde sale cada parte del número (D5).

## 3. Tests

- [x] 3.1 Borrar el test "repetir la animación no vuelve a llamar al
      servidor" y comprobar que `nivel-juego-repetir` ya no aparece en el
      fichero de tests.
- [x] 3.2 Test: en el revelado no existe ninguna acción de repetir
      (`nivel-juego-repetir` → `findsNothing`), con pin y sin pin.
- [x] 3.3 Reescribir "el lugar real y sus coordenadas se revelan" → el lugar
      real se revela sin coordenadas: sigue apareciendo `nombre_lugar` y
      `nivel-juego-coordenadas-reales` → `findsNothing`.
- [x] 3.4 Test: la tarjeta de puntos muestra los puntos ganados y no el
      máximo (`nivel-juego-puntos-maximos` → `findsNothing`), y quitar las
      aserciones de "/ 5.000" del test de la secuencia del revelado.
- [x] 3.5 Test: precisión y bonus comparten línea — mismo `dy` en el centro
      de los dos textos (`tester.getCenter`) cuando el bonus es mayor que 0.
      Corre a 900 px de ancho porque la fuente de `flutter_test` mide casi el
      doble que la real y en 390 px no cabría ni con el `Wrap` bien puesto
      (D3); el harness `_abrirNivel` acepta ahora el tamaño de pantalla.
- [x] 3.6 Test de guardia del encuadre (D6): a 390×844 la hoja del revelado
      cabe en la franja reservada y la llena en su mayor parte.
- [x] 3.7 Repasar el resto de la suite por aserciones que dependan de lo
      podado (`resumen_nivel_screen_test.dart` no se toca: su "Repetir
      animación" sigue).

## 4. Hallazgos de la revisión adversarial

- [x] 4.1 Sacar el factor de la franja a una constante pública
      (`fraccionDeLaHojaDeRevelado`) y medir contra ella en el test de
      guardia, en vez de repetir el número en los dos lados.
- [x] 4.2 Leer la barra inferior de `MediaQuery.paddingOf` y no de
      `viewPaddingOf`: `padding` es lo que consume el `SafeArea` de la hoja
      (con el teclado abierto, `viewPadding` haría reservar de más).
- [x] 4.3 Apuntar la barra inferior usada en `_barraInferiorDelRevelado` y
      recalcular el encuadre en `_alAvanzarLaCoreografia` si cambia a media
      coreografía, igual que ya se hacía con el tamaño del mapa.
- [x] 4.4 Dejar explícita en el test sin pin la mitad "sin pin" de la tarea
      3.2, con el comentario de por qué vive en ese test y no en uno propio.

## 5. Verificación y cierre

- [x] 5.1 `dart format` y `flutter analyze` limpios en `app/`.
- [x] 5.2 `flutter test` completo en verde (toda la suite, no solo el fichero
      tocado).
- [x] 5.3 Cobertura de las líneas tocadas de `nivel_juego_screen.dart`
      (96 % del fichero; lo que queda sin cubrir es el `_Destello` de antes).
- [ ] 5.4 Prueba en dispositivo: la hoja se ve claramente más baja, se ve más
      mapa por encima, y los dos pines siguen visibles y sin quedar tapados
      ni por el HUD ni por la hoja.
