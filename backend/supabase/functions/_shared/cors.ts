// El panel invoca estas funciones desde el navegador (localhost en desarrollo,
// Vercel en produccion), asi que hacen falta cabeceras CORS y responder al
// preflight. supabase-js manda authorization, apikey y content-type.

export const CABECERAS_CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-supabase-api-version',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

export function esPreflight(req: Request): boolean {
  return req.method === 'OPTIONS'
}
