## 1. Datos: `panel/src/lib/preguntas.ts`

- [x] 1.1 Definir tipos `Pregunta` (camelCase: id, tipo, nombreLugar,
      textoPregunta, imagenUrl, activo, usos: `{ tematicaNombre, nivelOrden,
      nivelId }[]`) y filas crudas (`snake_case`) de `desafios`,
      `nivel_desafios`, `niveles`, `tematicas`.
- [x] 1.2 Implementar `fetchPreguntas()`: consulta batch de `desafios`
      (todas las filas), `nivel_desafios`, `niveles`, `tematicas`; arma en
      memoria el array de asignaciones por desafío (D2 de design.md).
      Propaga cualquier error de Supabase.
- [x] 1.3 Implementar `eliminarPregunta(id)`: `delete` sobre `desafios`
      filtrando por `id`; si `error.code === '23503'`, relanzar un `Error`
      con mensaje "No se puede eliminar: esta pregunta está en uso o tiene
      respuestas registradas de jugadores."; cualquier otro error se
      propaga tal cual.
- [x] 1.4 Tests unitarios (`preguntas.test.ts`, mockeando `supabase.from`
      como en `dashboard.test.ts`): mapeo camelCase, cálculo de "usos" para
      un desafío en 0/1/varios niveles, propagación de error de fetch,
      `eliminarPregunta` éxito, `eliminarPregunta` con `23503` da el
      mensaje amigable, `eliminarPregunta` con otro error lo propaga.

## 2. Pantalla: `panel/src/pages/Preguntas.tsx`

- [x] 2.1 Cargar datos con `useEffect`/`useState` (mismo patrón que
      `Home.tsx`): loading, error, y datos listos.
- [x] 2.2 Cabecera: título, contador resumen, botón "Nueva pregunta"
      deshabilitado (`aria-disabled`, `title="Próximamente"`, sin
      `onClick`/navegación — D4).
- [x] 2.3 Buscador (nombre de lugar o texto de la pregunta,
      case-insensitive) como estado controlado.
- [x] 2.4 Filtros combinables: temática, nivel (opciones acotadas a la
      temática elegida, igual que el mockup), tipo, estado, y filtro "Sin
      asignar a ningún nivel"; botón "Limpiar filtros" visible solo si hay
      alguno activo.
- [x] 2.5 Aplicar búsqueda + filtros en cada render (sin `useMemo`,
      dataset pequeño, D2) y resetear a la página 1 cuando cambie
      cualquier filtro o búsqueda.
- [x] 2.6 Tabla: miniatura (imagen real para `tipo='imagen'` con
      `onError` a ícono; ícono para `video`/`pregunta_texto` — D5), nombre
      de lugar, badge de tipo, estado (con punto de color), indicador
      "Usado en N niveles"/"Sin asignar".
- [x] 2.7 Detalle del indicador de uso: al pasar el cursor o al abrirlo
      (elemento interactivo, no solo `title` nativo, para que sea
      testeable/accesible), lista cada `Temática · Nivel`.
- [x] 2.8 Acción "Editar" deshabilitada por fila (D4); acción "Eliminar"
      con `window.confirm` de confirmación, llamada a `eliminarPregunta`,
      quitar la fila del estado local en éxito, mostrar el mensaje de
      error devuelto (D3) sin tumbar el resto de la pantalla.
- [x] 2.9 Paginación: rango mostrado + controles anterior/siguiente/página
      concreta, deshabilitados en los extremos.
- [x] 2.10 Estado vacío por filtros (con CTA "Limpiar filtros") distinto
      del estado vacío por banco totalmente vacío (con CTA "Crear la
      primera pregunta", deshabilitada — D4).
- [x] 2.11 Tests (`Preguntas.test.tsx`, mockeando `../lib/preguntas` como
      `Home.test.tsx` mockea `../lib/dashboard`): fila por desafío (no por
      asignación) para uno usado en varios niveles, detalle de niveles al
      abrir el indicador, búsqueda, cada filtro combinado, filtro "sin
      asignar", paginación y su reset al filtrar, ambos estados vacíos,
      "Nueva pregunta"/"Editar" deshabilitados (`aria-disabled`, sin rol
      `link`/navegación), eliminar con éxito quita la fila, eliminar con
      error de "en uso" muestra el mensaje y conserva la fila.

## 3. Enrutado y navegación

- [x] 3.1 Añadir ruta `/preguntas` en `App.tsx` (dentro de `RequireAuth` +
      `PanelLayout`, como `/`).
- [x] 3.2 Habilitar el enlace "Preguntas/Desafíos" en
      `PanelLayout.tsx` (`enabled: true`, `to="/preguntas"`).
- [x] 3.3 Actualizar/extender `PanelLayout.test.tsx` si existe alguna
      aserción que dé por hecho que ese enlace está deshabilitado.

## 4. Verificación

- [x] 4.1 `npm run lint` y `npm run typecheck` (o script equivalente) en
      `panel/`.
- [x] 4.2 `npm test` en `panel/` con cobertura, todo en verde.
- [ ] 4.3 Probar manualmente en el navegador: navegar desde el nav,
      buscar, combinar filtros, filtro "sin asignar", paginar, abrir
      detalle de uso, eliminar un desafío sin uso y uno en uso (ver
      mensaje), estados vacíos, botones deshabilitados. (pendiente:
      corresponde a la fase de testing local del usuario)
