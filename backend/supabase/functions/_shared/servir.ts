// Envoltorio comun de las funciones de IA: preflight, autorizacion de admin y
// traduccion de cualquier fallo al conjunto cerrado de codigos.

import { CABECERAS_CORS, esPreflight } from './cors.ts'
import { ErrorFuncion, respuestaError, respuestaOk } from './errores.ts'
import { exigirAdmin } from './admin.ts'

export function servirFuncionIa(manejar: (peticion: unknown) => Promise<unknown>): void {
  Deno.serve(async (req) => {
    if (esPreflight(req)) return new Response('ok', { headers: CABECERAS_CORS })

    try {
      await exigirAdmin(req)

      let peticion: unknown
      try {
        peticion = await req.json()
      } catch {
        throw new ErrorFuncion('peticion_invalida', 'cuerpo no es JSON')
      }

      return respuestaOk(await manejar(peticion), CABECERAS_CORS)
    } catch (error) {
      if (error instanceof ErrorFuncion) {
        console.error(`[${error.codigo}] ${error.detalle ?? 'sin detalle'}`)
        return respuestaError(error.codigo, CABECERAS_CORS)
      }
      console.error('[openai_error] fallo inesperado:', error)
      return respuestaError('openai_error', CABECERAS_CORS)
    }
  })
}
