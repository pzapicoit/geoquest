// Conjunto cerrado de codigos de error de las funciones de IA (INT-113, D12).
//
// El panel traduce estos codigos a mensajes en castellano. Cualquier detalle
// tecnico se queda en los logs de la funcion: la respuesta nunca lleva el
// cuerpo crudo de OpenAI, que puede incluir fragmentos de la peticion.

export type CodigoError =
  | 'no_autorizado'
  | 'secreto_no_configurado'
  | 'peticion_invalida'
  | 'respuesta_invalida'
  | 'openai_error'

const ESTADO_HTTP: Record<CodigoError, number> = {
  no_autorizado: 401,
  secreto_no_configurado: 503,
  peticion_invalida: 400,
  respuesta_invalida: 502,
  openai_error: 502,
}

export class ErrorFuncion extends Error {
  constructor(
    readonly codigo: CodigoError,
    // Solo para los logs de la funcion, nunca para la respuesta.
    readonly detalle?: string,
  ) {
    super(codigo)
    this.name = 'ErrorFuncion'
  }
}

export function respuestaError(codigo: CodigoError, cabeceras: HeadersInit): Response {
  return new Response(JSON.stringify({ codigo }), {
    status: ESTADO_HTTP[codigo],
    headers: { ...Object.fromEntries(new Headers(cabeceras)), 'Content-Type': 'application/json' },
  })
}

export function respuestaOk(cuerpo: unknown, cabeceras: HeadersInit): Response {
  return new Response(JSON.stringify(cuerpo), {
    status: 200,
    headers: { ...Object.fromEntries(new Headers(cabeceras)), 'Content-Type': 'application/json' },
  })
}
