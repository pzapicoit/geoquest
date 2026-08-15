import { supabase } from './supabaseClient'
import type { TipoDesafio } from './preguntas'

export type TipoMedia = Extract<TipoDesafio, 'imagen' | 'video'>

export interface PreguntaDetalle {
  id: string
  tipo: TipoDesafio
  nombreLugar: string
  textoPregunta: string | null
  imagenUrl: string | null
  videoUrl: string | null
  latReal: number
  lngReal: number
  activo: boolean
}

interface DesafioDetalleRow {
  id: string
  tipo: TipoDesafio
  nombre_lugar: string
  texto_pregunta: string | null
  imagen_url: string | null
  video_url: string | null
  lat_real: number
  lng_real: number
  activo: boolean
}

export async function fetchPregunta(id: string): Promise<PreguntaDetalle> {
  const { data, error } = await supabase
    .from('desafios')
    .select(
      'id, tipo, nombre_lugar, texto_pregunta, imagen_url, video_url, lat_real, lng_real, activo',
    )
    .eq('id', id)
    .single()
  if (error) throw new Error(error.message)

  const row = data as DesafioDetalleRow
  return {
    id: row.id,
    tipo: row.tipo,
    nombreLugar: row.nombre_lugar,
    textoPregunta: row.texto_pregunta,
    imagenUrl: row.imagen_url,
    videoUrl: row.video_url,
    latReal: row.lat_real,
    lngReal: row.lng_real,
    activo: row.activo,
  }
}

export interface NivelParaAsignar {
  id: string
  tematicaNombre: string
  nivelOrden: number
  cantidadPreguntas: number
}

export async function fetchNivelesParaAsignar(): Promise<NivelParaAsignar[]> {
  const [
    { data: niveles, error: nivelesError },
    { data: tematicas, error: tematicasError },
    { data: asignaciones, error: asignacionesError },
  ] = await Promise.all([
    supabase.from('niveles').select('id, orden, tematica_id'),
    supabase.from('tematicas').select('id, nombre'),
    supabase.from('nivel_desafios').select('nivel_id'),
  ])
  if (nivelesError) throw nivelesError
  if (tematicasError) throw tematicasError
  if (asignacionesError) throw asignacionesError

  const nombrePorTematica = new Map(
    (tematicas ?? []).map((tematica) => [tematica.id as string, tematica.nombre as string]),
  )
  const cantidadPorNivel = new Map<string, number>()
  for (const fila of asignaciones ?? []) {
    const nivelId = fila.nivel_id as string
    cantidadPorNivel.set(nivelId, (cantidadPorNivel.get(nivelId) ?? 0) + 1)
  }

  return (niveles ?? [])
    .map((nivel) => ({
      id: nivel.id as string,
      tematicaNombre: nombrePorTematica.get(nivel.tematica_id as string) ?? 'Temática desconocida',
      nivelOrden: nivel.orden as number,
      cantidadPreguntas: cantidadPorNivel.get(nivel.id as string) ?? 0,
    }))
    .sort((a, b) => a.tematicaNombre.localeCompare(b.tematicaNombre) || a.nivelOrden - b.nivelOrden)
}

const MAX_MEDIA_BYTES = 50 * 1024 * 1024

const MIME_PERMITIDOS: Record<TipoMedia, string[]> = {
  imagen: ['image/jpeg', 'image/png', 'image/webp'],
  video: ['video/mp4'],
}

const EXTENSION_POR_MIME: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'video/mp4': 'mp4',
}

export function validarArchivoMedia(tipo: TipoMedia, file: File): string | null {
  if (!MIME_PERMITIDOS[tipo].includes(file.type)) {
    return tipo === 'imagen' ? 'La imagen debe ser JPG, PNG o WEBP.' : 'El vídeo debe ser MP4.'
  }
  if (file.size > MAX_MEDIA_BYTES) {
    return 'El archivo supera el tamaño máximo de 50 MiB.'
  }
  return null
}

export async function subirMediaDesafio(id: string, tipo: TipoMedia, file: File): Promise<string> {
  const extension = EXTENSION_POR_MIME[file.type] ?? file.name.split('.').pop() ?? 'bin'
  const ruta = `${tipo}/${id}.${extension}`

  const { error } = await supabase.storage
    .from('challenge-media')
    .upload(ruta, file, { upsert: true, contentType: file.type })
  if (error) throw new Error(error.message)

  const { data } = supabase.storage.from('challenge-media').getPublicUrl(ruta)
  return data.publicUrl
}

export interface GuardarPreguntaInput {
  id: string | null
  tipo: TipoDesafio
  nombreLugar: string
  textoPregunta: string | null
  latReal: number
  lngReal: number
  activo: boolean
  archivo: File | null
  imagenUrlActual: string | null
  videoUrlActual: string | null
}

export async function guardarPregunta(input: GuardarPreguntaInput): Promise<{ id: string }> {
  const id = input.id ?? crypto.randomUUID()

  let imagenUrl = input.tipo === 'imagen' ? input.imagenUrlActual : null
  let videoUrl = input.tipo === 'video' ? input.videoUrlActual : null

  if (input.archivo && (input.tipo === 'imagen' || input.tipo === 'video')) {
    const url = await subirMediaDesafio(id, input.tipo, input.archivo)
    if (input.tipo === 'imagen') imagenUrl = url
    else videoUrl = url
  }

  const { error } = await supabase.from('desafios').upsert({
    id,
    tipo: input.tipo,
    imagen_url: imagenUrl,
    video_url: videoUrl,
    texto_pregunta: input.tipo === 'pregunta_texto' ? input.textoPregunta : null,
    lat_real: input.latReal,
    lng_real: input.lngReal,
    nombre_lugar: input.nombreLugar,
    activo: input.activo,
  })
  if (error) throw new Error(error.message)

  return { id }
}

export interface AsignacionResultado {
  nivelId: string
  error: string | null
}

export async function asignarPreguntaANiveles(
  desafioId: string,
  nivelIds: string[],
): Promise<AsignacionResultado[]> {
  if (nivelIds.length === 0) return []

  const { data: asignaciones, error } = await supabase
    .from('nivel_desafios')
    .select('nivel_id, orden')
    .in('nivel_id', nivelIds)
  if (error) throw new Error(error.message)

  const maxOrdenPorNivel = new Map<string, number>()
  for (const fila of asignaciones ?? []) {
    const nivelId = fila.nivel_id as string
    maxOrdenPorNivel.set(
      nivelId,
      Math.max(maxOrdenPorNivel.get(nivelId) ?? 0, fila.orden as number),
    )
  }

  return Promise.all(
    nivelIds.map(async (nivelId) => {
      const orden = (maxOrdenPorNivel.get(nivelId) ?? 0) + 1
      const { error: insertError } = await supabase
        .from('nivel_desafios')
        .insert({ nivel_id: nivelId, desafio_id: desafioId, orden })
      return { nivelId, error: insertError ? insertError.message : null }
    }),
  )
}
