-- INT-84: niveles.nombre -- nombre editable opcional del nivel, mostrado
-- en la pantalla de Nivel/Recorrido junto (no en sustitucion) de `orden`.
-- Nullable y sin default: los niveles existentes siguen identificandose
-- por `orden` donde ya se hacia (Preguntas.tsx, preguntaForm.ts).
alter table niveles add column nombre text;
