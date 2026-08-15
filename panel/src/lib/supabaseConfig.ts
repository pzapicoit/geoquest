interface SupabaseEnv {
  VITE_SUPABASE_URL?: string
  VITE_SUPABASE_PUBLISHABLE_KEY?: string
}

export interface SupabaseConfig {
  url: string
  publishableKey: string
}

export function resolveSupabaseConfig(env: SupabaseEnv): SupabaseConfig {
  if (!env.VITE_SUPABASE_URL) {
    throw new Error(
      'Falta la variable de entorno VITE_SUPABASE_URL. Copia panel/.env.example a panel/.env.local y rellénala.',
    )
  }

  if (!env.VITE_SUPABASE_PUBLISHABLE_KEY) {
    throw new Error(
      'Falta la variable de entorno VITE_SUPABASE_PUBLISHABLE_KEY. Copia panel/.env.example a panel/.env.local y rellénala.',
    )
  }

  return {
    url: env.VITE_SUPABASE_URL,
    publishableKey: env.VITE_SUPABASE_PUBLISHABLE_KEY,
  }
}
