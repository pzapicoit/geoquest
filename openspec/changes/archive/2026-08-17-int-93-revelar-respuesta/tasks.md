## 1. Backend: `responder_desafio` revela el desafío respondido

- [x] 1.1 Crear migración `responder_desafio_revela_lugar` en
      `backend/supabase/migrations/`
- [x] 1.2 `drop function responder_desafio(uuid, uuid, double precision,
      double precision)` (D1: cambia el tipo de retorno, no basta un
      `create or replace`)
- [x] 1.3 Recrear `responder_desafio` con `returns jsonb`, conservando
      `security definer`, `set search_path = public`, la validación de
      pertenencia del intento y el `insert` en `respuestas_desafio`
- [x] 1.4 Devolver el `jsonb` con la respuesta registrada
      (`distancia_km`, `puntos` y la fila) más el revelado del desafío:
      `lat_real`, `lng_real`, `nombre_lugar` y `puntos_maximos`
      (D3: `calcular_puntaje(0)`, no una constante)
- [x] 1.5 `revoke execute ... from public` / `grant execute ... to
      authenticated` de la firma nueva
- [x] 1.6 Comentarios de la migración referenciando D1/D2/D3 y dejando
      dicho que el trigger y las funciones de cálculo no se tocan (D14)

## 2. Gateway de la app

- [x] 2.1 `RespuestaDesafio` gana `latitudReal`, `longitudReal`,
      `nombreLugar` y `puntosMaximos`
- [x] 2.2 `mapearRespuestaDesafio` lee el `jsonb` nuevo, aceptando
      `distancia_km` como número o como texto igual que hoy
- [x] 2.3 Actualizar el comentario de la clase: ya no es cierto que la
      respuesta no incluya la ubicación real
- [x] 2.4 Tests de mapeo: respuesta completa, `distancia_km` como texto y
      campo del revelado ausente o inválido

## 3. Mapa: cámara encuadrable y segundo pin

- [x] 3.1 `CamaraMapa` (escala + desplazamiento) y
      `MapaMundiController.camaraPara(coordenadas, {margenes})` con los
      recortes de zoom y desplazamiento ya existentes (D5)
- [x] 3.2 `MapaMundiController.aplicarCamara(camara)` para adoptar un
      encuadre sin pasar por gestos
- [x] 3.3 `pinReal` y `progresoDeLaLinea` en el controlador, con su
      limpieza al pasar de desafío (D8)
- [x] 3.4 `interpolarGranCirculo(desde, hasta, puntos)`: slerp sobre
      vectores unitarios, en su propio fichero de `app/lib/mapa/` (D6)
- [x] 3.5 `trocearEnGuiones(polilinea, patron)`: troceado de la polilínea
      en segmentos de guión/hueco en espacio de pantalla (D6)
- [x] 3.6 Tests del controlador: encuadre de dos coordenadas dentro del
      área útil con márgenes distintos arriba y abajo, tope de zoom
      máximo con coordenadas casi iguales, tope de escala mínima con
      coordenadas antipodales
- [x] 3.7 Tests de las funciones puras: el gran círculo pasa por sus
      extremos y por el punto medio esperado, y el troceado respeta el
      patrón y la longitud total

## 4. Mapa: dibujo del revelado

- [x] 4.1 `_PintorPin` parametrizado con colores de relleno y halo, y
      rótulo sobre el pin (D7)
- [x] 4.2 Pin real dibujado desde `controller.pinReal`, con su color, su
      rótulo y su entrada con rebote; rótulo "Tu pin" en el del jugador
      solo cuando hay revelado
- [x] 4.3 `CustomPainter` de la línea punteada en espacio de pantalla,
      alimentado por el gran círculo, el troceado y la proyección del
      controlador (D6)
- [x] 4.4 `MapaMundi` acepta `interactivo`: sin `GestureDetector` activo y
      sin botones de zoom cuando es `false`
- [x] 4.5 Tests de widget del mapa: con pin real se dibujan los dos pines,
      en modo no interactivo un toque no coloca pin y no hay botones de
      zoom

## 5. Pantalla: fase de revelado y su coreografía

- [x] 5.1 Estado `_Revelado` (respuesta del servidor + pin confirmado +
      índice del desafío) y entrada en la fase al responder, sin avanzar
      ni limpiar el pin (D8)
- [x] 5.2 `AnimationController` único de la coreografía, con los tramos
      del diseño recortados por tiempo: pin real, encuadre, línea, contador
      de distancia, destello, contador de puntos (D4)
- [x] 5.3 Encuadre animado entre la cámara actual y `camaraPara` con los
      márgenes de la hoja de resultado, con `easeInOutCubic`, recalculando el
      destino si la pantalla cambia de tamaño a media animación (D5)
- [x] 5.4 Progreso de la línea y contadores conectados a la animación, sin
      reconstruir la pantalla entera en cada fotograma
- [x] 5.5 El mapa pasa a `interactivo: false` durante el revelado
- [x] 5.6 Formateo de la distancia: entero con separador de millares y un
      decimal por debajo de 10 km (D12)

## 6. Pantalla: hoja de resultado y avance

- [x] 6.1 Hoja de resultado con su entrada desde abajo: miniatura,
      "Ubicación real" con nombre y coordenadas del lugar, tarjeta de
      distancia y tarjeta de puntos sobre el máximo
- [x] 6.2 Miniatura por tipo de pista: imagen para `imagen`, distintivo
      del tipo para `video` y `pregunta_texto` (D9)
- [x] 6.3 Botón de continuar: "Siguiente" o "Ver resultados" en el último
      desafío, activo desde el primer instante del revelado (D13)
- [x] 6.4 "Siguiente" suma los puntos al puntaje del intento, limpia pin,
      pin real y línea, y abre la pista del desafío siguiente
- [x] 6.5 "Ver resultados" vuelve al camino de niveles (INT-94 sigue fuera
      de alcance)
- [x] 6.6 "Repetir animación" relanza la secuencia sin llamar al servidor
      ni tocar el puntaje acumulado (D11)
- [x] 6.7 HUD durante el revelado: el puntaje sube con el contador y el
      segmento del desafío revelado cuenta como respondido; la X sigue
      visible (D10)

## 7. Tests de la pantalla

- [x] 7.1 Confirmar entra en el revelado: no avanza de desafío, conserva
      el pin y muestra la hoja de resultado
- [x] 7.2 La secuencia acaba con la distancia y los puntos del servidor, y
      el HUD con el puntaje anterior más esos puntos
- [x] 7.3 Nombre del lugar y coordenadas reales visibles en la hoja
- [x] 7.4 Miniatura: imagen en un desafío de tipo imagen, distintivo en
      uno de vídeo y en uno de pregunta de texto
- [x] 7.5 El revelado no avanza solo aunque pase el tiempo de la animación
- [x] 7.6 "Siguiente" abre la pista del desafío siguiente con el mapa
      limpio; en el último desafío el botón se rotula "Ver resultados" y
      devuelve al camino
- [x] 7.7 "Repetir animación" no llama otra vez a `responder_desafio` y
      deja el puntaje acumulado igual
- [x] 7.8 Un fallo de `responder_desafio` no entra en el revelado, avisa y
      conserva el pin (regresión de INT-92)

## 8. Verificación manual contra el proyecto remoto

- [x] 8.1 `supabase db push` contra el proyecto remoto enlazado
- [x] 8.2 Llamar `responder_desafio` como jugador → la respuesta trae
      `distancia_km`, `puntos`, `lat_real`, `lng_real`, `nombre_lugar` y
      `puntos_maximos`
- [x] 8.3 Volver a llamarla con el mismo `intento_id`/`desafio_id` → falla
      por el `unique`, sin registrar una segunda respuesta
- [x] 8.4 Llamarla con un `intento_id` ajeno → falla y no revela nada
- [x] 8.5 Confirmar que `select` sobre `desafios` sigue vacío para un
      jugador y que `desafios_para_jugar` e `iniciar_intento_nivel` siguen
      sin `lat_real`/`lng_real`/`nombre_lugar` (D2)
- [ ] 8.6 (Testing local, pendiente del usuario) Jugar un nivel completo en
      el dispositivo: revelado de cada
      desafío, encuadre con los dos pines visibles, línea, contadores,
      puntaje del HUD y "Ver resultados" en el último
- [ ] 8.7 (Testing local, pendiente del usuario) Comprobar el rendimiento
      del encuadre animado en dispositivo (el
      mundo se repinta en cada fotograma del tramo de cámara)
