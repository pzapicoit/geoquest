// Acceso a OpenAI desde las funciones de IA (INT-113, D8, D10).
//
// La clave vive solo aqui, en la variable de entorno geo_open_api del runtime:
// nunca en la base, nunca en el repo, nunca en el navegador. Los modelos salen
// de entorno para poder cambiarlos sin redeploy de codigo.

import { ErrorFuncion } from './errores.ts'

// Medido contra este prompt (INT-113, testing local): gpt-5 no devolvia nada en
// 90 s —es un modelo de razonamiento y aqui se le pide recordar lugares, no
// razonar—, mientras gpt-4.1 responde en unos 4 s con coordenadas correctas.
// Cambiarlo es una variable de entorno, no un deploy.
export const MODELO_TEXTO_POR_DEFECTO = 'gpt-4.1'
export const MODELO_IMAGEN_POR_DEFECTO = 'gpt-image-1'

export function claveOpenai(): string {
  const clave = Deno.env.get('geo_open_api')
  if (!clave) throw new ErrorFuncion('secreto_no_configurado')
  return clave
}

export function modeloTexto(): string {
  return Deno.env.get('GEOQUEST_MODELO_TEXTO') ?? MODELO_TEXTO_POR_DEFECTO
}

export function modeloImagen(): string {
  return Deno.env.get('GEOQUEST_MODELO_IMAGEN') ?? MODELO_IMAGEN_POR_DEFECTO
}

// Corta la espera con AbortController en vez de dejar la invocacion colgada
// hasta el limite del runtime: el panel necesita un error, no un timeout mudo.
export async function pedirAOpenai(
  ruta: string,
  cuerpo: unknown,
  esperaMaxMs: number,
): Promise<unknown> {
  const corte = new AbortController()
  const temporizador = setTimeout(() => corte.abort(), esperaMaxMs)

  try {
    const respuesta = await fetch(`https://api.openai.com/v1/${ruta}`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${claveOpenai()}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(cuerpo),
      signal: corte.signal,
    })

    if (!respuesta.ok) {
      const detalle = await respuesta.text()
      throw new ErrorFuncion('openai_error', `${respuesta.status} ${detalle.slice(0, 500)}`)
    }

    return await respuesta.json()
  } catch (error) {
    if (error instanceof ErrorFuncion) throw error
    if (error instanceof DOMException && error.name === 'AbortError') {
      throw new ErrorFuncion('openai_error', `sin respuesta en ${esperaMaxMs} ms`)
    }
    throw new ErrorFuncion('openai_error', error instanceof Error ? error.message : String(error))
  } finally {
    clearTimeout(temporizador)
  }
}
