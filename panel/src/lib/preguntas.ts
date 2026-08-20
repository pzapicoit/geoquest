import { supabase } from './supabaseClient'
import type { Dificultad } from './dificultad'

export type TipoDesafio = 'imagen' | 'pregunta_texto' | 'video'

export interface Pregunta {
  id: string
  nombre: string
  tipo: TipoDesafio
  nombreLugar: string
  textoPregunta: string | null
  imagenUrl: string | null
  activo: boolean
  dificultad: Dificultad
  tematicaId: string
  tematicaNombre: string
}

interface DesafioRow {
  id: string
  nombre: string
  tipo: TipoDesafio
  nombre_lugar: string
  texto_pregunta: string | null
  imagen_url: string | null
  activo: boolean
  dificultad: Dificultad
  tematica_id: string
}

interface TematicaRow {
  id: string
  nombre: string
}

export async function fetchPreguntas(): Promise<Pregunta[]> {
  const [{ data: desafios, error: desafiosError }, { data: tematicas, error: tematicasError }] =
    await Promise.all([
      supabase
        .from('desafios')
        .select(
          'id, nombre, tipo, nombre_lugar, texto_pregunta, imagen_url, activo, dificultad, tematica_id',
        ),
      supabase.from('tematicas').select('id, nombre'),
    ])
  if (desafiosError) throw desafiosError
  if (tematicasError) throw tematicasError

  const nombrePorTematica = new Map(
    ((tematicas ?? []) as TematicaRow[]).map((tematica) => [tematica.id, tematica.nombre]),
  )

  return ((desafios ?? []) as DesafioRow[]).map((desafio) => ({
    id: desafio.id,
    nombre: desafio.nombre,
    tipo: desafio.tipo,
    nombreLugar: desafio.nombre_lugar,
    textoPregunta: desafio.texto_pregunta,
    imagenUrl: desafio.imagen_url,
    activo: desafio.activo,
    dificultad: desafio.dificultad,
    tematicaId: desafio.tematica_id,
    tematicaNombre: nombrePorTematica.get(desafio.tematica_id) ?? 'Temática desconocida',
  }))
}

export async function actualizarDificultadPregunta(
  id: string,
  dificultad: Dificultad,
): Promise<void> {
  const { error } = await supabase.from('desafios').update({ dificultad }).eq('id', id)
  if (error) throw new Error(error.message)
}

export async function actualizarActivoPregunta(id: string, activo: boolean): Promise<void> {
  const { error } = await supabase.from('desafios').update({ activo }).eq('id', id)
  if (error) throw new Error(error.message)
}

export async function eliminarPregunta(id: string): Promise<void> {
  const { error } = await supabase.from('desafios').delete().eq('id', id)
  if (!error) return

  if (error.code === '23503') {
    throw new Error(
      'No se puede eliminar: esta pregunta tiene respuestas registradas de jugadores.',
    )
  }
  throw new Error(error.message)
}
