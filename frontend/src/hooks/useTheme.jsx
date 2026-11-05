import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react'
import { useSession } from './useSession'

const ThemeContext = createContext(null)
const STORAGE_KEY = 'vf-tema'

function initialTheme(profileTheme) {
  if (profileTheme === 'claro' || profileTheme === 'escuro') return profileTheme
  try {
    const stored = window.localStorage.getItem(STORAGE_KEY)
    if (stored === 'claro' || stored === 'escuro') return stored
  } catch {
    // localStorage may be blocked; the default is fine.
  }
  return 'claro'
}

export function ThemeProvider({ children }) {
  const { profile, updateProfile } = useSession()
  const [theme, setThemeState] = useState(() => initialTheme(profile?.tema))

  useEffect(() => {
    if (profile?.tema && profile.tema !== theme) setThemeState(profile.tema)
    // Only follow the server when it actually changes.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [profile?.tema])

  useEffect(() => {
    document.documentElement.dataset.theme = theme
    try {
      window.localStorage.setItem(STORAGE_KEY, theme)
    } catch {
      // Ignore storage failures.
    }
  }, [theme])

  const setTheme = useCallback(
    async (next) => {
      if (next !== 'claro' && next !== 'escuro') return
      setThemeState(next)
      try {
        await updateProfile({ tema: next })
      } catch {
        // The theme still applies locally; the next session syncs it.
      }
    },
    [updateProfile],
  )

  const toggle = useCallback(() => {
    setTheme(theme === 'claro' ? 'escuro' : 'claro')
  }, [setTheme, theme])

  const value = useMemo(() => ({ theme, setTheme, toggle }), [theme, setTheme, toggle])
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>
}

export function useTheme() {
  const context = useContext(ThemeContext)
  if (!context) throw new Error('useTheme precisa estar dentro de ThemeProvider')
  return context
}
