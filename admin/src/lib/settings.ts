/** 管理端设置，localStorage 持久化 + 模块级缓存（fetch 同步读取） */

export interface Settings {
  /** 管理接口鉴权令牌，请求头 X-Admin-Token */
  token: string
}

const STORAGE_KEY = 'mashangdu.admin.settings'

let cache: Settings | null = null

export function loadSettings(): Settings {
  if (cache) return cache
  let next: Settings = { token: '' }
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (raw) {
      // 旧版本数据含 baseUrl 字段，此处只读取 token，多余字段自然忽略
      const parsed = JSON.parse(raw) as Partial<Settings>
      next = {
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
  cache = { token: s.token }
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(cache))
  } catch {
    // 忽略持久化失败（如隐私模式），内存缓存仍可用
  }
}
