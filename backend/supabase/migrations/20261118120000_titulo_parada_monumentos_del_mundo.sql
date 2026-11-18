-- Hotfix de datos (INT-142): la parada 1 del camino se titulaba
-- "Monumentos de Europa", pero iniciar_intento_parada sortea sus preguntas de
-- toda la tematica Monumentos en dificultad 'facil', sin filtro por region. En
-- partidas reales salian la Estatua de la Libertad o Machu Picchu, asi que el
-- titulo prometia algo que el sorteo no cumple.
--
-- Se corrige el titulo, no el sorteo: filtrar por region exigiria un modelo de
-- regiones que hoy no existe. "Monumentos del Mundo" describe el pool real y
-- distingue la parada de las 4 y 8 (misma tematica, sin nombre propio).
--
-- La condicion sobre el nombre actual hace la migracion idempotente y evita
-- pisar un titulo que alguien haya cambiado desde el panel entretanto.
update camino
   set nombre = 'Monumentos del Mundo'
 where id = '5d240f52-2141-4237-b7ee-253fa822087c'
   and nombre = 'Monumentos de Europa';
