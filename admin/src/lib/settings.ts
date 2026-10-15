/** 服务器连接设置，localStorage 持久化 + 模块级缓存（fetch 同步读取） */

export interface Settings {
  /** 服务器 Base URL，空 = 同源（dev 由 Vite proxy 转发） */
  baseUrl: string
  /** 管理接口鉴权令牌，请求头 X-Admin-Token */
  token: string
}

const STORAGE_KEY = 'mashangdu.admin.settings'

let cache: Settings | null = null

export function loadSettings(): Settings {
  if (cache) return cache
  let next: Settings = { baseUrl: '', token: '' }
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (raw) {
      const parsed = JSON.parse(raw) as Partial<Settings>
      next = {
        baseUrl: typeof parsed.baseUrl === 'string' ? parsed.baseUrl : '',
        token: typeof parsed.token === 'string' ? parsed.token : '',
      }
    }
  } catch {
    // 存储损坏时回退默认值
  }
  cache = next
  return cache
}

export function saveSettings(s: Settings): void {
  cache = { baseUrl: s.baseUrl, token: s.token }
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(cache))
  } catch {
    // 忽略持久化失败（如隐私模式），内存缓存仍可用
  }
}
