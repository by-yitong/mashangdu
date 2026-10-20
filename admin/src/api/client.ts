import { loadSettings } from '../lib/settings'
import type {
  AdminCommentPage,
  AdminStats,
  AdminUserPage,
  CourseImportResult,
} from './types'

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
  // FormData 分支：不手动设置 Content-Type，让浏览器自动携带 multipart boundary
  const isFormData = options.body instanceof FormData
  const headers: Record<string, string> = {}
  if (options.body !== undefined && !isFormData) headers['Content-Type'] = 'application/json'
  if (token) headers['X-Admin-Token'] = token

  let res: Response
  try {
    res = await fetch(`/api/v1${path}`, {
      method: options.method ?? 'GET',
      headers,
      body:
        options.body === undefined
          ? undefined
          : isFormData
            ? (options.body as FormData)
            : JSON.stringify(options.body),
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

/** GET /api/v1/admin/comments 查询参数 */
export interface AdminCommentQuery {
  courseSlug?: string
  page?: number
  pageSize?: number
}

/** 评论管理：分页查询评论列表（可按课程筛选） */
export async function listComments(query: AdminCommentQuery = {}): Promise<AdminCommentPage> {
  const search = new URLSearchParams()
  if (query.courseSlug) search.set('courseSlug', query.courseSlug)
  if (query.page !== undefined) search.set('page', String(query.page))
  if (query.pageSize !== undefined) search.set('pageSize', String(query.pageSize))
  const qs = search.toString()
  return api<AdminCommentPage>(`/admin/comments${qs ? `?${qs}` : ''}`)
}

/** 评论管理：删除单条评论 */
export async function deleteComment(id: number): Promise<{ deleted: number }> {
  return api<{ deleted: number }>(`/admin/comments/${id}`, { method: 'DELETE' })
}

/** 课程管理：上传课程包 zip（multipart 字段 file），返回导入结果 */
export async function importCoursePackage(file: File): Promise<CourseImportResult> {
  const form = new FormData()
  form.append('file', file)
  return api<CourseImportResult>('/admin/courses/import', { method: 'POST', body: form })
}

/** 概况页：读取全站统计（指标 + 热门章节/最新用户/最新评论） */
export async function getStats(): Promise<AdminStats> {
  return api<AdminStats>('/admin/stats')
}

/** GET /api/v1/admin/users 查询参数 */
export interface AdminUserQuery {
  page?: number
  pageSize?: number
  /** 用户名模糊搜索 */
  q?: string
}

/** 用户管理：分页查询用户列表（可按用户名搜索） */
export async function listUsers(query: AdminUserQuery = {}): Promise<AdminUserPage> {
  const search = new URLSearchParams()
  if (query.page !== undefined) search.set('page', String(query.page))
  if (query.pageSize !== undefined) search.set('pageSize', String(query.pageSize))
  if (query.q) search.set('q', query.q)
  const qs = search.toString()
  return api<AdminUserPage>(`/admin/users${qs ? `?${qs}` : ''}`)
}

/** 用户管理：删除用户（级联清除其评论/点赞/阅读记录） */
export async function deleteUser(id: number): Promise<{ deleted: boolean }> {
  return api<{ deleted: boolean }>(`/admin/users/${id}`, { method: 'DELETE' })
}
