import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { FORBIDDEN_EVENT } from './api/client'
import { useSettings } from './SettingsContext'

export type ToastType = 'success' | 'error' | 'info'

export interface ToastItem {
  id: number
  type: ToastType
  text: string
}

type PushToast = (type: ToastType, text: string) => void

const ToastContext = createContext<PushToast | null>(null)

const TOAST_STYLES: Record<ToastType, string> = {
  success: 'border-teal-200 bg-teal-50 text-teal-900',
  error: 'border-red-200 bg-red-50 text-red-900',
  info: 'border-track bg-card text-ink',
}

function ToastRow({ item }: { item: ToastItem }) {
  return (
    <div
      role="status"
      className={`pointer-events-auto rounded-xl border px-3.5 py-2.5 text-sm shadow-sm ${TOAST_STYLES[item.type]}`}
    >
      {item.text}
    </div>
  )
}

export function ToastProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<ToastItem[]>([])
  const nextIdRef = useRef(0)
  const { update } = useSettings()

  const push = useCallback<PushToast>((type, text) => {
    nextIdRef.current += 1
    const id = nextIdRef.current
    setItems((prev) => [...prev.slice(-3), { id, type, text }])
    window.setTimeout(() => {
      setItems((prev) => prev.filter((t) => t.id !== id))
    }, 3600)
  }, [])

  // 任何接口返回 403（令牌失效/被服务端移除）时：提示、清空 token、跳登录页。
  // ToastProvider 位于 RouterProvider 之外，不能用 useNavigate，直接改 hash（hash 路由）；
  // 已在 /login 时不再触发，避免登录页自己的验证请求引起重复提示/跳转。
  useEffect(() => {
    const handler = () => {
      const path = window.location.hash.replace(/^#/, '').split('?')[0]
      if (path === '/login') return
      push('error', '登录已失效，请重新登录')
      update({ token: '' })
      window.location.hash = '#/login'
    }
    window.addEventListener(FORBIDDEN_EVENT, handler)
    return () => window.removeEventListener(FORBIDDEN_EVENT, handler)
  }, [push, update])

  const value = useMemo(() => push, [push])

  return (
    <ToastContext.Provider value={value}>
      {children}
      <div className="pointer-events-none fixed right-4 top-16 z-[100] flex w-80 flex-col gap-2">
        {items.map((t) => (
          <ToastRow key={t.id} item={t} />
        ))}
      </div>
    </ToastContext.Provider>
  )
}

export function useToast(): PushToast {
  const push = useContext(ToastContext)
  if (!push) throw new Error('useToast 必须在 ToastProvider 内使用')
  return push
}
