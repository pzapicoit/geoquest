import { useEffect, useState } from 'react'
import { supabase } from './supabaseClient'
import { useSession } from './useSession'

interface AdminProfileState {
  nombre: string | null
  loading: boolean
}

export function useAdminProfile(): AdminProfileState {
  const { session } = useSession()
  const [nombre, setNombre] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let isMounted = true

    if (!session) {
      Promise.resolve().then(() => {
        if (!isMounted) return
        setNombre(null)
        setLoading(false)
      })
      return () => {
        isMounted = false
      }
    }

    Promise.resolve(supabase.from('profiles').select('nombre').eq('id', session.user.id).single())
      .then(({ data }) => {
        if (!isMounted) return
        setNombre(data?.nombre ?? null)
      })
      .finally(() => {
        if (!isMounted) return
        setLoading(false)
      })

    return () => {
      isMounted = false
    }
  }, [session])

  return { nombre, loading }
}
