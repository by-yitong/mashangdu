import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { api, errMsg } from '../api/client'
import type { ChapterMeta, CourseDetail, CourseInput } from '../api/types'
import { ConfirmDialog, Modal } from '../components/Modal'
import { CourseForm } from '../components/CourseForm'
import { EmptyBlock, ErrorBlock, LoadingBlock } from '../components/States'
import { LanguageTag } from '../components/LanguageTag'
import { btnDangerGhost, btnGhost, btnPrimary } from '../components/ui'
import { fmtTime } from '../lib/format'
import { useToast } from '../ToastProvider'

type Status = 'loading' | 'ready' | 'error'

export function CourseDetailPage() {
  const { slug = '' } = useParams()
  const navigate = useNavigate()
  const push = useToast()

  const [status, setStatus] = useState<Status>('loading')
  const [course, setCourse] = useState<CourseDetail | null>(null)
  const [loadError, setLoadError] = useState('')

  const [editing, setEditing] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const [confirmingCourse, setConfirmingCourse] = useState(false)
  const [deletingCourse, setDeletingCourse] = useState(false)
  const [pendingChapter, setPendingChapter] = useState<ChapterMeta | null>(null)
  const [deletingChapter, setDeletingChapter] = useState(false)

  const load = useCallback(async () => {
    setStatus('loading')
    setLoadError('')
    try {
      const data = await api<CourseDetail>(`/courses/${encodeURIComponent(slug)}`)
      setCourse(data)
      setStatus('ready')
    } catch (e) {
      setLoadError(errMsg(e))
      setStatus('error')
    }
  }, [slug])

  useEffect(() => {
    void load()
  }, [load])

  const chapters = useMemo(
    () => (course?.chapters ? [...course.chapters].toSorted((a, b) => a.order - b.order) : []),
    [course],
  )

  const handleUpdateCourse = async (input: CourseInput) => {
    setSubmitting(true)
    try {
      await api(`/admin/courses/${encodeURIComponent(slug)}`, { method: 'PUT', body: input })
      push('success', '课程信息已更新')
      setEditing(false)
      await load()
    } catch (e) {
      push('error', `更新失败：${errMsg(e)}`)
    } finally {
      setSubmitting(false)
    }
  }

  const handleDeleteCourse = async () => {
    setDeletingCourse(true)
    try {
      await api(`/admin/courses/${encodeURIComponent(slug)}`, { method: 'DELETE' })
      push('success', `课程「${course?.title ?? slug}」已删除`)
      navigate('/')
    } catch (e) {
      push('error', `删除失败：${errMsg(e)}`)
      setDeletingCourse(false)
    }
  }

  const handleDeleteChapter = async (chapter: ChapterMeta) => {
    setDeletingChapter(true)
    try {
      await api(`/admin/courses/${encodeURIComponent(slug)}/chapters/${encodeURIComponent(chapter.slug)}`, {
        method: 'DELETE',
      })
      push('success', `章节「${chapter.title}」已删除`)
      setPendingChapter(null)
      await load()
    } catch (e) {
      push('error', `删除失败：${errMsg(e)}`)
    } finally {
      setDeletingChapter(false)
    }
  }

  if (status === 'loading') {
    return <LoadingBlock text="加载课程详情…" />
  }
  if (status === 'error') {
    return (
      <div className="flex flex-col gap-4">
        <Link to="/" className={`${btnGhost} self-start`}>
          ← 返回课程列表
        </Link>
        <ErrorBlock message={loadError} onRetry={() => void load()} />
      </div>
    )
  }
  if (!course) return null

  return (
    <div className="flex flex-col gap-4">
      <Link to="/" className={`${btnGhost} self-start`}>
        ← 返回课程列表
      </Link>

      {/* 课程信息卡 */}
      <section className="rounded-card border border-track bg-card p-[18px] pb-4 shadow-sm">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-2">
              <LanguageTag language={course.language} />
              <span className="font-mono text-xs text-inkmuted">{course.slug}</span>
            </div>
            <h1 className="mt-2 text-[28px] font-bold leading-tight text-ink">{course.title}</h1>
            <p className="mt-1.5 max-w-2xl text-[13px] leading-relaxed text-inkmuted">
              {course.summary || '暂无简介'}
            </p>
            <p className="mt-2 font-mono text-xs text-inkmuted">
              排序 {course.sort_order} · 更新于 {fmtTime(course.updated_at)}
            </p>
          </div>
          <div className="flex shrink-0 gap-2">
            <button type="button" className={btnGhost} onClick={() => setEditing(true)}>
              编辑课程
            </button>
            <button type="button" className={btnDangerGhost} onClick={() => setConfirmingCourse(true)}>
              删除课程
            </button>
          </div>
        </div>
      </section>

      {/* 章节列表卡 */}
      <section className="rounded-card border border-track bg-card p-[18px] pb-4 shadow-sm">
        <div className="mb-3 flex items-center justify-between gap-3">
          <h2 className="text-xl font-bold text-ink">章节列表</h2>
          <Link to={`/courses/${encodeURIComponent(slug)}/chapters/new`} className={btnPrimary}>
            ＋ 新建章节
          </Link>
        </div>

        {chapters.length === 0 ? (
          <EmptyBlock title="还没有章节" hint="点击「新建章节」编写第一章内容" />
        ) : (
          <ul className="flex flex-col gap-2">
            {chapters.map((chapter) => (
              <li
                key={chapter.slug}
                className="flex items-center gap-3 rounded-xl border border-track px-4 py-3 transition hover:border-accent/40"
              >
                <span className="w-7 shrink-0 text-center font-mono text-xs text-inkmuted">
                  {String(chapter.order).padStart(2, '0')}
                </span>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-semibold text-ink">{chapter.title}</p>
                  <p className="truncate font-mono text-xs text-inkmuted">
                    {chapter.slug} · {fmtTime(chapter.updated_at)}
                  </p>
                </div>
                <Link
                  to={`/courses/${encodeURIComponent(slug)}/chapters/${encodeURIComponent(chapter.slug)}`}
                  className={`${btnGhost} h-8`}
                >
                  编辑
                </Link>
                <button
                  type="button"
                  className={`${btnDangerGhost} h-8`}
                  onClick={() => setPendingChapter(chapter)}
                >
                  删除
                </button>
              </li>
            ))}
          </ul>
        )}
      </section>

      <Modal open={editing} title="编辑课程" onClose={() => setEditing(false)}>
        <CourseForm
          initial={course}
          submitting={submitting}
          submitLabel="保存修改"
          onSubmit={(input) => void handleUpdateCourse(input)}
          onCancel={() => setEditing(false)}
        />
      </Modal>

      <ConfirmDialog
        open={confirmingCourse}
        title="删除课程"
        message={`确定删除课程「${course.title}」吗？课程下的 ${chapters.length} 个章节将一并删除，此操作不可恢复。`}
        loading={deletingCourse}
        onConfirm={() => void handleDeleteCourse()}
        onCancel={() => setConfirmingCourse(false)}
      />

      <ConfirmDialog
        open={pendingChapter !== null}
        title="删除章节"
        message={`确定删除章节「${pendingChapter?.title ?? ''}」吗？此操作不可恢复。`}
        loading={deletingChapter}
        onConfirm={() => pendingChapter && void handleDeleteChapter(pendingChapter)}
        onCancel={() => setPendingChapter(null)}
      />
    </div>
  )
}
