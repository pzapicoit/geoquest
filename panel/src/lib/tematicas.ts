import { supabase } from './supabaseClient'

export interface Tematica {
  id: string
  nombre: string
  imagenPortada: string
  orden: number
  activo: boolean
  cantidadParadas: number
  // Estilo que la generación con IA aplica a las imágenes de esta temática.
  // Gobierna solo la ilustración, no qué lugares se proponen (INT-113 delta-1).
  promptImagen: string | null
}

interface TematicaRow {
  id: string
  nombre: string
  imagen_portada: string
  orden: number
  activo: boolean
  prompt_imagen: string | null
}

interface CaminoRow {
  tematica_id: string
}

export async function fetchTematicas(): Promise<Tematica[]> {
  const [{ data: tematicas, error: tematicasError }, { data: camino, error: caminoError }] =
    await Promise.all([
      supabase
        .from('tematicas')
        .select('id, nombre, imagen_portada, orden, activo, prompt_imagen')
        .order('orden', { ascending: true }),
      supabase.from('camino').select('tematica_id'),
    ])
  if (tematicasError) throw tematicasError
  if (caminoError) throw caminoError

  const cantidadPorTematica = new Map<string, number>()
  for (const parada of (camino ?? []) as CaminoRow[]) {
    cantidadPorTematica.set(
      parada.tematica_id,
      (cantidadPorTematica.get(parada.tematica_id) ?? 0) + 1,
    )
  }

  return ((tematicas ?? []) as TematicaRow[]).map((tematica) => ({
    id: tematica.id,
    nombre: tematica.nombre,
    imagenPortada: tematica.imagen_portada,
    orden: tematica.orden,
    activo: tematica.activo,
    cantidadParadas: cantidadPorTematica.get(tematica.id) ?? 0,
    promptImagen: tematica.prompt_imagen,
  }))
}

const MAX_PORTADA_BYTES = 4 * 1024 * 1024
const MIME_PERMITIDOS_PORTADA = ['image/jpeg', 'image/png']
const EXTENSION_POR_MIME: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
}

export function validarImagenPortada(file: File): string | null {
  if (!MIME_PERMITIDOS_PORTADA.includes(file.type)) {
    return 'La portada debe ser JPG o PNG.'
  }
  if (file.size > MAX_PORTADA_BYTES) {
    return 'El archivo supera el tamaño máximo de 4 MB.'
  }
  return null
}

export async function subirPortadaTematica(id: string, file: File): Promise<string> {
  const extension = EXTENSION_POR_MIME[file.type] ?? file.name.split('.').pop() ?? 'bin'
  const ruta = `tematicas/${id}.${extension}`

  const { error } = await supabase.storage
    .from('challenge-media')
    .upload(ruta, file, { upsert: true, contentType: file.type })
  if (error) throw new Error(error.message)

  const { data } = supabase.storage.from('challenge-media').getPublicUrl(ruta)
  return data.publicUrl
}

export interface GuardarTematicaInput {
  id: string | null
  nombre: string
  activo: boolean
  archivo: File | null
  imagenPortadaActual: string | null
  promptImagen: string | null
}

export async function guardarTematica(input: GuardarTematicaInput): Promise<{ id: string }> {
  const id = input.id ?? crypto.randomUUID()
  const promptImagen = input.promptImagen?.trim() ? input.promptImagen.trim() : null

  let imagenPortada = input.imagenPortadaActual
  if (input.archivo) {
    imagenPortada = await subirPortadaTematica(id, input.archivo)
  }
  if (!imagenPortada) {
    throw new Error('La temática necesita una imagen de portada.')
  }

  if (input.id) {
    const { error } = await supabase
      .from('tematicas')
      .update({
        nombre: input.nombre,
        imagen_portada: imagenPortada,
        activo: input.activo,
        prompt_imagen: promptImagen,
      })
      .eq('id', input.id)
    if (error) throw new Error(error.message)
    return { id }
  }

  const { data: existentes, error: ordenError } = await supabase.from('tematicas').select('orden')
  if (ordenError) throw new Error(ordenError.message)

  const siguienteOrden =
    Math.max(0, ...((existentes ?? []) as { orden: number }[]).map((t) => t.orden)) + 1

  const { error } = await supabase.from('tematicas').insert({
    id,
    nombre: input.nombre,
    imagen_portada: imagenPortada,
    orden: siguienteOrden,
    activo: input.activo,
    prompt_imagen: promptImagen,
  })
  if (error) throw new Error(error.message)

  return { id }
}

export async function eliminarTematica(id: string): Promise<void> {
  const { error } = await supabase.from('tematicas').delete().eq('id', id)
  if (!error) return

  if (error.code === '23503') {
    throw new Error(
      'No se puede eliminar: esta temática todavía tiene preguntas propias. Bórralas o reasígnalas primero.',
    )
  }
  throw new Error(error.message)
}

export async function actualizarActivoTematica(id: string, activo: boolean): Promise<void> {
  const { error } = await supabase.from('tematicas').update({ activo }).eq('id', id)
  if (error) throw new Error(error.message)
}

export async function reordenarTematicas(idsEnOrden: string[]): Promise<void> {
  const { error } = await supabase.rpc('reordenar_tematicas', { ids_en_orden: idsEnOrden })
  if (error) throw new Error(error.message)
}
