import { loadSettings } from '../lib/settings'

/** 响应信封 {"code":"OK","message":"ok","data":...} */
export interface ApiEnvelope<T> {
  code: string
  message: string
  data: T
}

export class ApiError extends Error {
  readonly code: string
  readonly status: number

  constructor(code: string, message: string, status: number) {
    super(message)
    this.name = 'ApiError'
    this.code = code
    this.status = status
  }
}

/** 403 时派发的全局事件，ToastProvider 监听后清 token 并跳转登录页 */
export const FORBIDDEN_EVENT = 'mashangdu:forbidden'

export function errMsg(e: unknown): string {
  if (e instanceof ApiError) return e.message
  if (e instanceof Error) return e.message
  return '请求失败'
}

export interface ApiOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE'
  body?: unknown
}

/**
 * 统一请求入口：路径以 /api/v1 为前缀，固定同源请求（前端将嵌入 Go 二进制，与后端永远同源）。
 * 成功返回信封 data；失败抛 ApiError（含后端 message）。
 */
export async function api<T>(path: string, options: ApiOptions = {}): Promise<T> {
  const { token } = loadSettings()
  const headers: Record<string, string> = {}
  if (options.body !== undefined) headers['Content-Type'] = 'application/json'
  if (token) headers['X-Admin-Token'] = token

  let res: Response
  try {
    res = await fetch(`/api/v1${path}`, {
      method: options.method ?? 'GET',
      headers,
      body: options.body === undefined ? undefined : JSON.stringify(options.body),
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
    if (res.status === 403) window.dispatchEvent(new Event(FORBIDDEN_EVENT))
    throw new ApiError(env.code || 'INTERNAL', env.message || `HTTP ${res.status}`, res.status)
  }
  return env.data as T
}
