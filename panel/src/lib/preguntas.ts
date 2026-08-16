import { supabase } from './supabaseClient'

export type TipoDesafio = 'imagen' | 'pregunta_texto' | 'video'

export interface UsoNivel {
  nivelId: string
  tematicaNombre: string
  nivelOrden: number
}

export interface Pregunta {
  id: string
  tipo: TipoDesafio
  nombreLugar: string
  textoPregunta: string | null
  imagenUrl: string | null
  activo: boolean
  usos: UsoNivel[]
}

interface DesafioRow {
  id: string
  tipo: TipoDesafio
  nombre_lugar: string
  texto_pregunta: string | null
  imagen_url: string | null
  activo: boolean
}

interface NivelDesafioRow {
  desafio_id: string
  nivel_id: string
}

interface NivelRow {
  id: string
  orden: number
  tematica_id: string
}

interface TematicaRow {
  id: string
  nombre: string
}

export async function fetchPreguntas(): Promise<Pregunta[]> {
  const [
    { data: desafios, error: desafiosError },
    { data: asignaciones, error: asignacionesError },
  ] = await Promise.all([
    supabase.from('desafios').select('id, tipo, nombre_lugar, texto_pregunta, imagen_url, activo'),
    supabase.from('nivel_desafios').select('desafio_id, nivel_id'),
  ])
  if (desafiosError) throw desafiosError
  if (asignacionesError) throw asignacionesError

  const filasAsignacion = (asignaciones ?? []) as NivelDesafioRow[]
  const nivelIds = [...new Set(filasAsignacion.map((asignacion) => asignacion.nivel_id))]

  const { data: niveles, error: nivelesError } =
    nivelIds.length > 0
      ? await supabase.from('niveles').select('id, orden, tematica_id').in('id', nivelIds)
      : { data: [] as NivelRow[], error: null }
  if (nivelesError) throw nivelesError

  const tematicaIds = [...new Set((niveles ?? []).map((nivel) => nivel.tematica_id))]
  const { data: tematicas, error: tematicasError } =
    tematicaIds.length > 0
      ? await supabase.from('tematicas').select('id, nombre').in('id', tematicaIds)
      : { data: [] as TematicaRow[], error: null }
  if (tematicasError) throw tematicasError

  const nivelPorId = new Map((niveles ?? []).map((nivel) => [nivel.id, nivel]))
  const nombrePorTematica = new Map(
    (tematicas ?? []).map((tematica) => [tematica.id, tematica.nombre]),
  )

  const usosPorDesafio = new Map<string, UsoNivel[]>()
  for (const asignacion of filasAsignacion) {
    const nivel = nivelPorId.get(asignacion.nivel_id)
    if (!nivel) continue

    const usos = usosPorDesafio.get(asignacion.desafio_id) ?? []
    usos.push({
      nivelId: nivel.id,
      tematicaNombre: nombrePorTematica.get(nivel.tematica_id) ?? 'Temática desconocida',
      nivelOrden: nivel.orden,
    })
    usosPorDesafio.set(asignacion.desafio_id, usos)
  }

  return ((desafios ?? []) as DesafioRow[]).map((desafio) => ({
    id: desafio.id,
    tipo: desafio.tipo,
    nombreLugar: desafio.nombre_lugar,
    textoPregunta: desafio.texto_pregunta,
    imagenUrl: desafio.imagen_url,
    activo: desafio.activo,
    usos: usosPorDesafio.get(desafio.id) ?? [],
  }))
}

export async function eliminarPregunta(id: string): Promise<void> {
  const { error } = await supabase.from('desafios').delete().eq('id', id)
  if (!error) return

  if (error.code === '23503') {
    throw new Error(
      'No se puede eliminar: esta pregunta está en uso o tiene respuestas registradas de jugadores.',
    )
  }
  throw new Error(error.message)
}
