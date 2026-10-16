/** 后端 API 数据结构（契约冻结） */

export interface Course {
  slug: string
  title: string
  summary: string
  language: string
  color: string
  sort_order: number
  chapter_count?: number
  created_at?: string
  updated_at?: string
}

export interface ChapterMeta {
  slug: string
  title: string
  order: number
  updated_at?: string
}

export interface CourseDetail extends Course {
  chapters: ChapterMeta[]
}

export interface ChapterDetail extends ChapterMeta {
  content_md: string
  /** 兼容字段：部分接口可能返回 sort_order 而非 order */
  sort_order?: number
}

/** POST/PUT 课程请求体 */
export interface CourseInput {
  slug: string
  title: string
  summary: string
  language: string
  color: string
  sort_order: number
}

/** POST/PUT 章节请求体 */
export interface ChapterInput {
  slug: string
  title: string
  content_md: string
  sort_order: number
}

/** App 发布版本（契约冻结，列表按 versionCode 降序） */
export interface AppVersion {
  id: number
  version: string
  versionCode: number
  notes: string
  apkUrl: string
  force: boolean
  enabled: boolean
  /** 发布时间（=createdAt） */
  releasedAt: string
  updatedAt: string
}

/** POST /api/v1/admin/app-versions 请求体 */
export interface AppVersionCreateInput {
  version: string
  versionCode: number
  notes: string
  apkUrl: string
  force: boolean
}

/** PUT /api/v1/admin/app-versions/:id 请求体 */
export interface AppVersionUpdateInput extends AppVersionCreateInput {
  enabled: boolean
}
