import { useState, type FormEvent } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import { ApiError, errMsg, type ApiEnvelope } from '../api/client'
import { Field, btnPrimary, inputCls } from '../components/ui'
import { useSettings } from '../SettingsContext'

/**
 * 用表单填写的 token 直接请求鉴权接口验证（成功前 token 不落盘）。
 * 不复用 api()：它从已保存的 settings 读 token，发不出表单里未保存的令牌；
 * 且 403 时会派发全局 FORBIDDEN_EVENT，登录页自己的验证失败不应触发"登录已失效"。
 * 端点与请求头契约与 api() 完全一致：GET /api/v1/admin/app-versions + X-Admin-Token（同源相对路径）。
 */
async function verifyToken(token: string): Promise<void> {
  let res: Response
  try {
    res = await fetch(`/api/v1/admin/app-versions`, {
      headers: { 'X-Admin-Token': token },
    })
  } catch {
    throw new ApiError('NETWORK', '网络请求失败，请检查网络', 0)
  }
  let env: ApiEnvelope<unknown>
  try {
    env = (await res.json()) as ApiEnvelope<unknown>
  } catch {
    throw new ApiError('INTERNAL', `HTTP ${res.status}（响应不是合法 JSON）`, res.status)
  }
  if (!res.ok || env.code !== 'OK') {
    throw new ApiError(env.code || 'INTERNAL', env.message || `HTTP ${res.status}`, res.status)
  }
}

export function LoginPage() {
  const { update } = useSettings()
  const navigate = useNavigate()
  const location = useLocation()
  const [token, setToken] = useState('')
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)

  // 守卫跳转时记录的来路（RequireToken 传入的 location），登录成功后回跳
  const from = (location.state as { from?: { pathname?: string } } | null)?.from?.pathname ?? '/'

  const handleSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    if (busy) return
    const nextToken = token.trim()
    if (!nextToken) {
      setError('请输入管理令牌')
      return
    }
    setBusy(true)
    setError('')
    try {
      await verifyToken(nextToken)
      update({ token: nextToken })
      navigate(from, { replace: true })
    } catch (err) {
      setError(
        err instanceof ApiError && err.status === 403
          ? '令牌错误，或服务端未启用管理端'
          : errMsg(err),
      )
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-paper px-4 text-ink">
      <div className="w-full max-w-[380px] rounded-card border border-track bg-card p-6 shadow-sm">
        <div className="mb-6 flex items-center gap-3">
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-accent text-base font-bold text-white">
            码
          </span>
          <div>
            <h1 className="text-base font-bold leading-tight text-ink">码上读后台</h1>
            <p className="mt-0.5 text-xs text-inkmuted">输入管理令牌登录</p>
          </div>
        </div>

        <form className="flex flex-col gap-4" onSubmit={(e) => void handleSubmit(e)}>
          <Field label="管理令牌">
            <input
              className={`${inputCls} font-mono`}
              type="password"
              autoComplete="current-password"
              autoFocus
              spellCheck={false}
              value={token}
              onChange={(e) => setToken(e.target.value)}
              placeholder="管理员令牌"
              disabled={busy}
            />
          </Field>

          {error ? (
            <p
              role="alert"
              className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-600"
            >
              {error}
            </p>
          ) : null}

          <button
            type="submit"
            className={`${btnPrimary} mt-1 w-full focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/40 focus-visible:ring-offset-1`}
            disabled={busy}
          >
            {busy ? '验证中…' : '登录'}
          </button>
        </form>
      </div>
    </div>
  )
}
