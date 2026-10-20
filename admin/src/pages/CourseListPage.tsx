import { useCallback, useEffect, useState } from 'react'
import { api, errMsg } from '../api/client'
import type { Course, CourseImportResult, CourseInput } from '../api/types'
import { CourseCard } from '../components/CourseCard'
import { CourseForm } from '../components/CourseForm'
import { CourseImportDialog } from '../components/CourseImportDialog'
import { Modal } from '../components/Modal'
import { EmptyBlock, ErrorBlock, LoadingBlock } from '../components/States'
import { btnGhost, btnPrimary } from '../components/ui'
import { useToast } from '../ToastProvider'

type Status = 'loading' | 'ready' | 'error'

export function CourseListPage() {
  const [status, setStatus] = useState<Status>('loading')
  const [courses, setCourses] = useState<Course[]>([])
  const [loadError, setLoadError] = useState('')
  const [creating, setCreating] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const [importing, setImporting] = useState(false)
  const push = useToast()

  const load = useCallback(async () => {
    setStatus('loading')
    setLoadError('')
    try {
      const data = await api<Course[]>('/courses')
      setCourses(data)
      setStatus('ready')
    } catch (e) {
      setLoadError(errMsg(e))
      setStatus('error')
    }
  }, [])

  useEffect(() => {
    void load()
  }, [load])

  const handleCreate = async (input: CourseInput) => {
    setSubmitting(true)
    try {
      await api('/admin/courses', { method: 'POST', body: input })
      push('success', `课程「${input.title}」已创建`)
      setCreating(false)
      await load()
    } catch (e) {
      push('error', `创建失败：${errMsg(e)}`)
    } finally {
      setSubmitting(false)
    }
  }

  /** 导入成功：沿用原课程导入页文案提示并刷新课程列表（弹窗保持打开展示明细） */
  const handleImported = useCallback(
    (result: CourseImportResult) => {
      push('success', `导入成功：${result.courses.length} 门课程、${result.images.count} 张图片`)
      void load()
    },
    [push, load],
  )

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-[32px] font-bold leading-tight text-ink">课程管理</h1>
          <p className="mt-1 text-[13px] text-inkmuted">
            {status === 'ready' ? `共 ${courses.length} 门课程` : '正在同步课程数据'}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button type="button" className={btnGhost} onClick={() => setImporting(true)}>
            导入课程
          </button>
          <button type="button" className={btnPrimary} onClick={() => setCreating(true)}>
            ＋ 新建课程
          </button>
        </div>
      </div>

      {status === 'loading' && <LoadingBlock />}
      {status === 'error' && <ErrorBlock message={loadError} onRetry={() => void load()} />}
      {status === 'ready' &&
        (courses.length === 0 ? (
          <EmptyBlock
            title="还没有课程"
            hint="点击「新建课程」创建第一门教程"
            action={
              <button type="button" className={btnPrimary} onClick={() => setCreating(true)}>
                ＋ 新建课程
              </button>
            }
          />
        ) : (
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {courses.map((course) => (
              <CourseCard key={course.slug} course={course} />
            ))}
          </div>
        ))}

      <CourseImportDialog
        open={importing}
        onClose={() => setImporting(false)}
        onImported={handleImported}
      />

      <Modal open={creating} title="新建课程" onClose={() => setCreating(false)}>
        <CourseForm
          submitting={submitting}
          submitLabel="创建课程"
          onSubmit={(input) => void handleCreate(input)}
          onCancel={() => setCreating(false)}
        />
      </Modal>
    </div>
  )
}
