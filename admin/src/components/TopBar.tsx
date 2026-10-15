import { useEffect, useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import { useSettings } from '../SettingsContext'
import { useToast } from '../ToastProvider'
import { Field, btnGhost, inputCls } from './ui'

export function TopBar() {
  const [open, setOpen] = useState(false)
  const { settings } = useSettings()

  const serverLabel = settings.baseUrl
    ? settings.baseUrl.replace(/^https?:\/\//, '').replace(/\/+$/, '')
    : '同源'

  return (
    <header className="sticky top-0 z-40 border-b border-track bg-card/90 backdrop-blur">
      <div className="mx-auto flex h-14 w-full max-w-6xl items-center justify-between px-4">
        <Link to="/" className="flex items-center gap-2">
          <span className="flex h-7 w-7 items-center justify-center rounded-lg bg-accent text-sm font-bold text-white">
            码
          </span>
          <span className="text-[15px] font-bold text-ink">码上读后台</span>
        </Link>

        <div className="relative flex items-center gap-3">
          <span className="hidden items-center gap-1.5 text-xs text-inkmuted sm:flex" title={`服务器：${serverLabel}`}>
            <span
              className={`h-2 w-2 rounded-full ${settings.token ? 'bg-accent' : 'bg-red-400'}`}
              aria-hidden
            />
            {serverLabel} · {settings.token ? 'Token 已配置' : '未配置 Token'}
          </span>
          <button type="button" className={`${btnGhost} h-8`} onClick={() => setOpen((v) => !v)}>
            <svg viewBox="0 0 20 20" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="1.6">
              <circle cx="10" cy="10" r="2.6" />
              <path d="M10 3v2M10 15v2M3 10h2M15 10h2M5.1 5.1l1.4 1.4M13.5 13.5l1.4 1.4M14.9 5.1l-1.4 1.4M6.5 13.5l-1.4 1.4" strokeLinecap="round" />
            </svg>
            设置
          </button>
          {open && <SettingsPopover onClose={() => setOpen(false)} />}
        </div>
      </div>
    </header>
  )
}

function SettingsPopover({ onClose }: { onClose: () => void }) {
  const { settings, update } = useSettings()
  const push = useToast()
  const [baseUrl, setBaseUrl] = useState(settings.baseUrl)
  const [token, setToken] = useState(settings.token)
  const rootRef = useRef<HTMLDivElement | null>(null)

  // 点击弹层外部关闭
  useEffect(() => {
    const onDown = (e: globalThis.MouseEvent) => {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) onClose()
    }
    document.addEventListener('mousedown', onDown)
    return () => document.removeEventListener('mousedown', onDown)
  }, [onClose])

  const handleSave = () => {
    update({ baseUrl: baseUrl.trim(), token: token.trim() })
    push('success', '设置已保存')
    onClose()
  }

  return (
    <div ref={rootRef} className="absolute right-0 top-11 z-50 w-80 rounded-card border border-track bg-card p-4 shadow-lg">
      <h3 className="mb-3 text-sm font-bold text-ink">服务器设置</h3>
      <div className="flex flex-col gap-3">
        <Field label="服务器 Base URL" hint="留空 = 同源（dev 模式由 Vite 代理到 localhost:8080）">
          <input
            className={`${inputCls} font-mono text-[13px]`}
            value={baseUrl}
            onChange={(e) => setBaseUrl(e.target.value)}
            placeholder="例如 http://192.168.1.10:8080"
          />
        </Field>
        <Field label="Admin Token" hint="管理接口鉴权请求头 X-Admin-Token；403 时请检查此项">
          <input
            className={`${inputCls} font-mono text-[13px]`}
            type="text"
            autoComplete="off"
            spellCheck={false}
            value={token}
            onChange={(e) => setToken(e.target.value)}
            placeholder="管理员令牌"
          />
        </Field>
      </div>
      <div className="mt-4 flex justify-end gap-2">
        <button type="button" className={btnGhost} onClick={onClose}>
          取消
        </button>
        <button type="button" className="inline-flex h-9 items-center rounded-full bg-accent px-4 text-sm font-medium text-white transition hover:bg-teal-700" onClick={handleSave}>
          保存
        </button>
      </div>
    </div>
  )
}
