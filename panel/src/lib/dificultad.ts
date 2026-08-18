export type Dificultad = 'facil' | 'normal' | 'intermedio' | 'dificil' | 'muy_dificil'

export const DIFICULTADES: { valor: Dificultad; label: string }[] = [
  { valor: 'facil', label: 'Fácil' },
  { valor: 'normal', label: 'Normal' },
  { valor: 'intermedio', label: 'Intermedio' },
  { valor: 'dificil', label: 'Difícil' },
  { valor: 'muy_dificil', label: 'Muy difícil' },
]

export const DIFICULTAD_LABEL: Record<Dificultad, string> = Object.fromEntries(
  DIFICULTADES.map((d) => [d.valor, d.label]),
) as Record<Dificultad, string>
