import { describe, it, expect } from 'vitest'
import { resolveSupabaseConfig } from './supabaseConfig'

describe('resolveSupabaseConfig', () => {
  it('devuelve la configuración cuando está completa', () => {
    const config = resolveSupabaseConfig({
      VITE_SUPABASE_URL: 'https://example.supabase.co',
      VITE_SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_test',
    })

    expect(config).toEqual({
      url: 'https://example.supabase.co',
      publishableKey: 'sb_publishable_test',
    })
  })

  it('falla explícitamente si falta la URL', () => {
    expect(() =>
      resolveSupabaseConfig({ VITE_SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_test' }),
    ).toThrow('VITE_SUPABASE_URL')
  })

  it('falla explícitamente si falta la clave publicable', () => {
    expect(() =>
      resolveSupabaseConfig({ VITE_SUPABASE_URL: 'https://example.supabase.co' }),
    ).toThrow('VITE_SUPABASE_PUBLISHABLE_KEY')
  })
})
