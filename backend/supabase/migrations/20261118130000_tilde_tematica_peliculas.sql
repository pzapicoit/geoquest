-- Hotfix de datos (INT-147): la temática de cine se llamaba "Peliculas", sin
-- tilde. Ese nombre lo ve el jugador en el camino, en la bienvenida
-- ("Siguiente: Peliculas") y en la clasificación por temática.
--
-- La condición sobre el nombre actual hace la migración idempotente y evita
-- pisar un nombre que alguien haya cambiado desde el panel entretanto.
update tematicas
   set nombre = 'Películas'
 where id = 'f6d78a61-6678-4fcf-89a0-e525aa5988df'
   and nombre = 'Peliculas';
