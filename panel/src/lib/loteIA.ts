// Guardado de un lote de preguntas generadas con IA (INT-113, D6).
//
// La imagen la sube el navegador con la sesión del admin, reutilizando la ruta
// de escritura que ya existe para el formulario de preguntas: la convención del
// bucket y sus políticas RLS no se reimplementan en la Edge Function.
//
// El orden "subir imagen → insertar fila" es obligado: el CHECK de `desafios`
// exige `imagen_url` no nulo cuando el tipo es `imagen`.

import { supabase } from './supabaseClient'
import { rutaMediaDesafio, subirMediaDesafio } from './preguntaForm'
import type { Dificultad } from './dificultad'

export interface CandidatoParaGuardar {
  nombre: string
  lat: number
  lng: number
  imagen: Blob | null
}

export type MotivoNoGuardado = 'sin_imagen' | 'fallo_subida' | 'fallo_insercion'

export interface ResultadoGuardado {
  nombre: string
  guardado: boolean
  motivo: MotivoNoGuardado | null
}

export interface LoteIA {
  tematicaId: string
  dificultad: Dificultad
  activo: boolean
  candidatos: CandidatoParaGuardar[]
}

function archivoDeImagen(id: string, imagen: Blob): File {
  return new File([imagen], id, { type: imagen.type || 'image/webp' })
}

export async function guardarLoteIA(lote: LoteIA): Promise<ResultadoGuardado[]> {
  const resultados: ResultadoGuardado[] = []

  for (const candidato of lote.candidatos) {
    if (!candidato.imagen) {
      resultados.push({ nombre: candidato.nombre, guardado: false, motivo: 'sin_imagen' })
      continue
    }

    const id = crypto.randomUUID()
    const archivo = archivoDeImagen(id, candidato.imagen)

    let imagenUrl: string
    try {
      imagenUrl = await subirMediaDesafio(id, 'imagen', archivo)
    } catch {
      resultados.push({ nombre: candidato.nombre, guardado: false, motivo: 'fallo_subida' })
      continue
    }

    const { error } = await supabase.from('desafios').insert({
      id,
      tipo: 'imagen',
      imagen_url: imagenUrl,
      video_url: null,
      texto_pregunta: null,
      lat_real: candidato.lat,
      lng_real: candidato.lng,
      nombre_lugar: candidato.nombre,
      activo: lote.activo,
      tematica_id: lote.tematicaId,
      dificultad: lote.dificultad,
    })

    if (error) {
      // Sin la fila, el objeto subido es basura que nadie referencia: un
      // reintento genera otro id y otra subida, así que se limpia aquí.
      await supabase.storage
        .from('challenge-media')
        .remove([rutaMediaDesafio(id, 'imagen', archivo)])
      resultados.push({ nombre: candidato.nombre, guardado: false, motivo: 'fallo_insercion' })
      continue
    }

    resultados.push({ nombre: candidato.nombre, guardado: true, motivo: null })
  }

  return resultados
}
