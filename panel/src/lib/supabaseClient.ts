import { createClient } from '@supabase/supabase-js'
import { resolveSupabaseConfig } from './supabaseConfig'

const { url, publishableKey } = resolveSupabaseConfig(import.meta.env)

export const supabase = createClient(url, publishableKey)
