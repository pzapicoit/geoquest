-- INT-116: separa tres responsabilidades hoy mezcladas en desafios.nombre_lugar
-- (que sirve a la vez de identificador de la pregunta y de respuesta real).
-- Ver design.md D1 de openspec/changes/int-116-objetivo-global-nombre-corto.
--
-- objetivo_global/nombre se crean nullable: la migracion de datos de
-- 20260819171000 los rellena antes de que esta misma se cierre a NOT NULL
-- (mismo patron que desafios.dificultad en INT-106). pista se queda nullable
-- de forma permanente -- es opcional por diseno, no transitoriamente.
alter table tematicas add column objetivo_global text;
alter table desafios add column nombre text;
alter table desafios add column pista text;
