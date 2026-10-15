import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react'
import { loadSettings, saveSettings, type Settings } from './lib/settings'

interface SettingsContextValue {
  settings: Settings
  update: (s: Settings) => void
}

const SettingsContext = createContext<SettingsContextValue | null>(null)

export function SettingsProvider({ children }: { children: ReactNode }) {
  const [settings, setSettings] = useState<Settings>(loadSettings)
  const update = useCallback((s: Settings) => {
    saveSettings(s)
    setSettings(s)
  }, [])
  const value = useMemo(() => ({ settings, update }), [settings, update])
  return <SettingsContext.Provider value={value}>{children}</SettingsContext.Provider>
}

export function useSettings(): SettingsContextValue {
  const ctx = useContext(SettingsContext)
  if (!ctx) throw new Error('useSettings 必须在 SettingsProvider 内使用')
  return ctx
}
