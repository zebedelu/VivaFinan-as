import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'
import { apiFetch } from '../services/api'

export const SessionContext = createContext(null)

const EMPTY = {
  session: null,
  user: null,
  profile: null,
  family: null,
  loading: true,
  profileError: null,
}

export function SessionProvider({ children }) {
  const [state, setState] = useState(EMPTY)

  const loadMe = useCallback(async () => {
    try {
      const me = await apiFetch('/me')
      setState((prev) => ({
        ...prev,
        user: me?.user || prev.user,
        profile: me?.profile ?? null,
        family: me?.family ?? null,
        loading: false,
        profileError: null,
      }))
      return me
    } catch (error) {
      if (error?.status === 401) {
        setState({ ...EMPTY, loading: false })
        return null
      }
      setState((prev) => ({ ...prev, loading: false, profileError: error }))
      return null
    }
  }, [])

  const applySession = useCallback(
    (session) => {
      setState((prev) => ({
        ...prev,
        session,
        user: session?.user ?? null,
        // With a session, wait for /me before rendering so a direct link does
        // not bounce through onboarding while the profile is still unknown.
        loading: Boolean(session),
        ...(session ? {} : { profile: null, family: null, profileError: null }),
      }))
      if (session) {
        // Avoid awaiting Supabase auth callbacks: the client can deadlock.
        setTimeout(() => {
          loadMe()
        }, 0)
      }
    },
    [loadMe],
  )

  useEffect(() => {
    let active = true

    supabase.auth
      .getSession()
      .then(({ data }) => {
        if (!active) return
        applySession(data?.session ?? null)
      })
      .catch(() => {
        if (active) setState({ ...EMPTY, loading: false })
      })

    const { data: subscription } = supabase.auth.onAuthStateChange((event, session) => {
      if (!active || event === 'INITIAL_SESSION') return
      applySession(session ?? null)
    })

    return () => {
      active = false
      subscription?.subscription?.unsubscribe?.()
    }
  }, [applySession])

  const signIn = useCallback(async (email, password) => {
    return supabase.auth.signInWithPassword({ email, password })
  }, [])

  const signUp = useCallback(async (email, password, nome) => {
    return supabase.auth.signUp({
      email,
      password,
      options: { data: nome ? { nome } : undefined },
    })
  }, [])

  const signOut = useCallback(async () => {
    try {
      await supabase.auth.signOut()
    } finally {
      setState({ ...EMPTY, loading: false })
    }
  }, [])

  const updateProfile = useCallback(async (patch) => {
    const result = await apiFetch('/me', { method: 'PATCH', body: patch })
    const profile = result?.profile || result
    setState((prev) => ({ ...prev, profile: { ...prev.profile, ...profile } }))
    return profile
  }, [])

  const refresh = useCallback(async () => {
    await loadMe()
  }, [loadMe])

  const value = useMemo(
    () => ({
      ...state,
      signIn,
      signUp,
      signOut,
      updateProfile,
      refresh,
      setSession: applySession,
    }),
    [state, signIn, signUp, signOut, updateProfile, refresh, applySession],
  )

  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>
}

export function useSession() {
  const context = useContext(SessionContext)
  if (!context) throw new Error('useSession precisa estar dentro de SessionProvider')
  return context
}
