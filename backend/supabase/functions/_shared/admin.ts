// Autorizacion de las funciones de IA (INT-113, D5).
//
// No se usa la clave secreta en ningun punto: la funcion habla con la base con
// la clave publicable mas el Authorization del invocador, de modo que la
// comprobacion se apoya en la misma frontera que el resto del sistema (RLS).
// La policy profiles_select_own (INT-76) es la que permite leer el propio rol.

import { createClient } from 'jsr:@supabase/supabase-js@2'
import { ErrorFuncion } from './errores.ts'

// Este proyecto tiene las claves legacy de tipo JWT desactivadas
// (spec backend-environment), asi que SUPABASE_ANON_KEY no sirve aqui y queda
// solo como ultimo recurso para no atar la funcion a este proyecto.
function clavePublicable(): string | undefined {
  const explicita = Deno.env.get('GEOQUEST_PUBLISHABLE_KEY')
  if (explicita) return explicita

  // La plataforma inyecta SUPABASE_PUBLISHABLE_KEYS (en plural) y su formato no
  // esta garantizado: puede venir como lista separada por comas o como JSON. Se
  // extrae la primera cosa con forma de clave publicable en vez de partir por
  // comas, porque una clave mal recortada aqui se manifiesta como un 401 que
  // parece "este usuario no es admin".
  const dePlataforma = Deno.env.get('SUPABASE_PUBLISHABLE_KEYS')
  const primera = dePlataforma?.match(/sb_publishable_[A-Za-z0-9_-]+/)?.[0]
  if (primera) return primera

  return Deno.env.get('SUPABASE_ANON_KEY')
}

export async function exigirAdmin(req: Request): Promise<void> {
  const authorization = req.headers.get('Authorization')
  const url = Deno.env.get('SUPABASE_URL')
  const clave = clavePublicable()

  if (!authorization || !url || !clave) {
    throw new ErrorFuncion('no_autorizado', 'falta Authorization, SUPABASE_URL o clave publicable')
  }

  const cliente = createClient(url, clave, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const { data: sesion, error: errorSesion } = await cliente.auth.getUser()
  if (errorSesion || !sesion.user) {
    throw new ErrorFuncion('no_autorizado', errorSesion?.message ?? 'sin usuario en el JWT')
  }

  const { data: perfil, error: errorPerfil } = await cliente
    .from('profiles')
    .select('role')
    .eq('id', sesion.user.id)
    .maybeSingle()

  // Un error aqui suele significar que la clave publicable de la funcion no es
  // valida para el proyecto; se distingue en los logs, no en la respuesta.
  if (errorPerfil) {
    throw new ErrorFuncion('no_autorizado', `lectura de profiles: ${errorPerfil.message}`)
  }
  if (perfil?.role !== 'admin') {
    throw new ErrorFuncion('no_autorizado', `rol del invocador: ${perfil?.role ?? 'sin perfil'}`)
  }
}
