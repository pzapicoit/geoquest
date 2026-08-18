import { supabase } from './supabaseClient'
import { DIFICULTAD_LABEL, type Dificultad } from './dificultad'

export interface MetricasHome {
  jugadoresTotales: number
  jugadoresActivos7d: number
  partidasHoy: number
  paradasActivas: number
}

export interface AlertaContenido {
  tipo: string
  referenciaId: string
  titulo: string
  detalle: Record<string, unknown>
  etiqueta: string
}

export interface EventoActividad {
  tipo: string
  ocurridoEn: string
  texto: string
  detalle: Record<string, unknown>
  etiqueta: string | null
}

interface MetricasHomeRow {
  jugadores_totales: number
  jugadores_activos_7d: number
  partidas_hoy: number
  paradas_activas: number
}

interface AlertaContenidoRow {
  tipo: string
  referencia_id: string
  titulo: string
  detalle: Record<string, unknown>
}

interface EventoActividadRow {
  tipo: string
  ocurrido_en: string
  texto: string
  detalle: Record<string, unknown>
}

export async function fetchMetricasHome(): Promise<MetricasHome> {
  const { data, error } = await supabase.rpc('metricas_home')
  if (error) throw error

  const row = (data as MetricasHomeRow[] | null)?.[0]
  if (!row) throw new Error('metricas_home no devolvió ninguna fila')

  return {
    jugadoresTotales: row.jugadores_totales,
    jugadoresActivos7d: row.jugadores_activos_7d,
    partidasHoy: row.partidas_hoy,
    paradasActivas: row.paradas_activas,
  }
}

// Nombre legible de una parada del camino: "<temática> · <dificultad>". Una
// consulta a `camino` y una a `tematicas` (batch por ids únicos), no una por
// fila.
async function resolveParadaEtiquetas(
  caminoIds: (string | undefined)[],
): Promise<Map<string, string>> {
  const etiquetas = new Map<string, string>()
  const ids = [...new Set(caminoIds.filter((id): id is string => Boolean(id)))]
  if (ids.length === 0) return etiquetas

  const { data: camino, error: caminoError } = await supabase
    .from('camino')
    .select('id, dificultad, tematica_id')
    .in('id', ids)
  if (caminoError) throw caminoError

  const tematicaIds = [...new Set((camino ?? []).map((parada) => parada.tematica_id as string))]
  const { data: tematicas, error: tematicasError } =
    tematicaIds.length > 0
      ? await supabase.from('tematicas').select('id, nombre').in('id', tematicaIds)
      : { data: [] as { id: string; nombre: string }[], error: null }
  if (tematicasError) throw tematicasError

  const nombrePorTematica = new Map(
    (tematicas ?? []).map((tematica) => [tematica.id, tematica.nombre]),
  )

  for (const parada of camino ?? []) {
    const nombreTematica = nombrePorTematica.get(parada.tematica_id) ?? 'Temática desconocida'
    etiquetas.set(
      parada.id,
      `${nombreTematica} · ${DIFICULTAD_LABEL[parada.dificultad as Dificultad]}`,
    )
  }

  return etiquetas
}

// Nombre legible de un desafío: "<lugar> (<tipo>)". Una sola consulta batch.
async function resolveDesafioEtiquetas(
  desafioIds: (string | undefined)[],
): Promise<Map<string, string>> {
  const etiquetas = new Map<string, string>()
  const ids = [...new Set(desafioIds.filter((id): id is string => Boolean(id)))]
  if (ids.length === 0) return etiquetas

  const { data, error } = await supabase
    .from('desafios')
    .select('id, tipo, nombre_lugar')
    .in('id', ids)
  if (error) throw error

  for (const desafio of data ?? []) {
    etiquetas.set(desafio.id, `${desafio.nombre_lugar} (${desafio.tipo})`)
  }

  return etiquetas
}

export async function fetchAlertasContenido(): Promise<AlertaContenido[]> {
  const { data, error } = await supabase.rpc('alertas_contenido')
  if (error) throw error

  const filas = (data ?? []) as AlertaContenidoRow[]
  const caminoIds = filas
    .filter((fila) => fila.tipo === 'nivel_baja_tasa')
    .map((fila) => fila.referencia_id)
  const desafioIds = filas
    .filter((fila) => fila.tipo === 'desafio_incompleto')
    .map((fila) => fila.referencia_id)

  const [paradaEtiquetas, desafioEtiquetas] = await Promise.all([
    resolveParadaEtiquetas(caminoIds),
    resolveDesafioEtiquetas(desafioIds),
  ])

  return filas.map((fila) => ({
    tipo: fila.tipo,
    referenciaId: fila.referencia_id,
    titulo: fila.titulo,
    detalle: fila.detalle,
    etiqueta:
      paradaEtiquetas.get(fila.referencia_id) ??
      desafioEtiquetas.get(fila.referencia_id) ??
      fila.titulo,
  }))
}

export async function fetchActividadReciente(limite = 20): Promise<EventoActividad[]> {
  const { data, error } = await supabase.rpc('actividad_reciente', { p_limite: limite })
  if (error) throw error

  const filas = (data ?? []) as EventoActividadRow[]
  const caminoIds = filas
    .filter((fila) => fila.tipo === 'nivel_superado')
    .map((fila) => fila.detalle?.camino_id as string | undefined)

  const paradaEtiquetas = await resolveParadaEtiquetas(caminoIds)

  return filas.map((fila) => ({
    tipo: fila.tipo,
    ocurridoEn: fila.ocurrido_en,
    texto: fila.texto,
    detalle: fila.detalle,
    etiqueta:
      fila.tipo === 'nivel_superado'
        ? (paradaEtiquetas.get(fila.detalle?.camino_id as string) ?? null)
        : null,
  }))
}
