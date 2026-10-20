import { useCallback, useMemo, useRef, useState, type ChangeEvent, type DragEvent, type KeyboardEvent } from 'react'
import { ApiError, errMsg, importCoursePackage } from '../api/client'
import type { CourseImportResult, ImportedCourse } from '../api/types'
import { Modal } from './Modal'
import { btnGhost, btnPrimary } from './ui'
import { useToast } from '../ToastProvider'

/** 弹窗内错误态：接口失败时的 code + message */
interface ImportFailure {
  code: string
  message: string
}

/** 字节数 → 人类可读（B/KB/MB/GB，保留 1-2 位小数） */
function fmtBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`
}

/** created/updated 徽标（沿用版本页徽标配色：teal=新建，中性=更新） */
function StateBadge({ state }: { state: ImportedCourse['state'] }) {
  return state === 'created' ? (
    <span className="inline-flex items-center rounded-full border border-teal-200 bg-teal-50 px-2 py-0.5 text-xs font-medium text-teal-700">
      新建
    </span>
  ) : (
    <span className="inline-flex items-center rounded-full border border-track bg-paper px-2 py-0.5 text-xs font-medium text-inkmuted">
      更新
    </span>
  )
}

/** 结果卡内单门课程行（key 使用 slug） */
function CourseRow({ course }: { course: ImportedCourse }) {
  return (
    <li className="flex items-center justify-between gap-3 border-b border-track/60 py-2.5 last:border-0">
      <div className="min-w-0">
        <p className="truncate text-sm font-medium text-ink" title={course.title}>
          {course.title}
        </p>
        <p className="truncate font-mono text-xs text-inkmuted" title={course.slug}>
          {course.slug}
        </p>
      </div>
      <div className="flex shrink-0 items-center gap-2.5">
        <span className="text-xs text-inkmuted">{course.chapters} 章</span>
        <StateBadge state={course.state} />
      </div>
    </li>
  )
}

interface UploadCardProps {
  file: File | null
  fileError: string
  dragging: boolean
  uploading: boolean
  onPick: (file: File | undefined) => void
  onDraggingChange: (dragging: boolean) => void
  onImport: () => void
  onClear: () => void
}

/** 上传卡：拖拽/点击选 zip + 导入按钮 + zip 布局说明 */
function UploadCard({
  file,
  fileError,
  dragging,
  uploading,
  onPick,
  onDraggingChange,
  onImport,
  onClear,
}: UploadCardProps) {
  const inputRef = useRef<HTMLInputElement>(null)

  const handleClick = useCallback(() => {
    if (uploading) return
    inputRef.current?.click()
  }, [uploading])

  const handleKeyDown = useCallback(
    (e: KeyboardEvent<HTMLDivElement>) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault()
        if (!uploading) inputRef.current?.click()
      }
    },
    [uploading],
  )

  const handleChange = useCallback(
    (e: ChangeEvent<HTMLInputElement>) => {
      onPick(e.target.files?.[0])
      e.target.value = '' // 允许再次选择同一文件
    },
    [onPick],
  )

  const handleDragOver = useCallback(
    (e: DragEvent<HTMLDivElement>) => {
      e.preventDefault()
      onDraggingChange(true)
    },
    [onDraggingChange],
  )

  const handleDragLeave = useCallback(
    (e: DragEvent<HTMLDivElement>) => {
      e.preventDefault()
      onDraggingChange(false)
    },
    [onDraggingChange],
  )

  const handleDrop = useCallback(
    (e: DragEvent<HTMLDivElement>) => {
      e.preventDefault()
      onDraggingChange(false)
      onPick(e.dataTransfer.files?.[0])
    },
    [onDraggingChange, onPick],
  )

  const fileSize = useMemo(() => (file ? fmtBytes(file.size) : ''), [file])

  return (
    <section className="flex flex-col rounded-card border border-track bg-card p-5">
      <h3 className="text-base font-bold text-ink">上传课程包</h3>

      <div
        role="button"
        tabIndex={0}
        aria-label="选择或拖入 zip 课程包"
        aria-disabled={uploading}
        onClick={handleClick}
        onKeyDown={handleKeyDown}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
        className={`mt-4 flex cursor-pointer flex-col items-center justify-center gap-2 rounded-2xl border-2 border-dashed px-4 py-8 text-center transition ${
          dragging
            ? 'border-accent bg-accentdim/60'
            : 'border-track bg-paper hover:border-accent/50 hover:bg-accentdim/30'
        }`}
      >
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.8"
          strokeLinecap="round"
          strokeLinejoin="round"
          className="h-8 w-8 text-accent"
          aria-hidden
        >
          <path d="M12 16V4" />
          <path d="m6 10 6-6 6 6" />
          <path d="M4 20h16" />
        </svg>
        <p className="text-sm font-medium text-ink">点击选择或拖入 zip 文件</p>
        <p className="text-xs text-inkmuted">仅支持 .zip 格式</p>
      </div>
      <input ref={inputRef} type="file" accept=".zip" className="hidden" onChange={handleChange} />

      {fileError && (
        <p role="alert" className="mt-2 text-xs text-red-600">
          {fileError}
        </p>
      )}

      {file && (
        <div className="mt-3 flex items-center justify-between gap-3 rounded-xl border border-track bg-paper px-3.5 py-2.5">
          <div className="min-w-0">
            <p className="truncate text-sm font-medium text-ink" title={file.name}>
              {file.name}
            </p>
            <p className="text-xs text-inkmuted">{fileSize}</p>
          </div>
          <button
            type="button"
            className={`${btnGhost} h-8 shrink-0`}
            disabled={uploading}
            onClick={onClear}
          >
            移除
          </button>
        </div>
      )}

      <div className="mt-4 flex justify-end">
        <button
          type="button"
          className={btnPrimary}
          disabled={!file || uploading}
          onClick={onImport}
        >
          {uploading && (
            <span
              className="h-4 w-4 animate-spin rounded-full border-2 border-white/70 border-t-transparent"
              aria-hidden
            />
          )}
          {uploading ? '导入中…' : '导入'}
        </button>
      </div>

      <p className="mt-4 border-t border-track pt-3 text-xs leading-relaxed text-inkmuted">
        zip 内约定布局：courses.json（课程清单）+ 各章节 .md + images/（章节插图）
      </p>
    </section>
  )
}

interface ResultCardProps {
  result: CourseImportResult | null
  failure: ImportFailure | null
  uploading: boolean
}

/** 结果卡：成功展示课程明细 + 图片统计；失败展示错误码与详情；未导入时为引导空态 */
function ResultCard({ result, failure, uploading }: ResultCardProps) {
  const imageStats = useMemo(
    () => (result ? { count: result.images.count, size: fmtBytes(result.images.bytes) } : null),
    [result],
  )

  return (
    <section className="flex flex-col rounded-card border border-track bg-card p-5" aria-busy={uploading}>
      <h3 className="text-base font-bold text-ink">导入结果</h3>

      {uploading && (
        <div className="mt-4 flex items-center justify-center gap-2.5 rounded-2xl border border-track bg-paper py-10 text-sm text-inkmuted">
          <span
            className="h-4 w-4 animate-spin rounded-full border-2 border-accent border-t-transparent"
            aria-hidden
          />
          正在上传并导入课程包…
        </div>
      )}

      {!uploading && failure && (
        <div className="mt-4 rounded-2xl border border-red-200 bg-red-50/60 p-4">
          <p className="text-sm font-semibold text-red-700">导入失败</p>
          <p className="mt-1.5 font-mono text-xs text-red-600">{failure.code}</p>
          <p className="mt-1 text-[13px] text-red-700">{failure.message}</p>
        </div>
      )}

      {!uploading && !failure && result && imageStats && (
        <>
          <p className="mt-1 text-[13px] text-inkmuted">
            共导入 {result.courses.length} 门课程，图片 {imageStats.count} 张（{imageStats.size}）
          </p>
          <ul className="mt-1">
            {result.courses.map((course) => (
              <CourseRow key={course.slug} course={course} />
            ))}
          </ul>
        </>
      )}

      {!uploading && !failure && !result && (
        <div className="mt-4 flex items-center justify-center rounded-2xl border border-dashed border-track bg-paper px-4 py-8 text-center">
          <p className="text-[13px] leading-relaxed text-inkmuted">
            还没有导入记录
            <br />
            选择课程包 zip 并点击「导入」后，这里会展示每门课程的创建/更新明细
          </p>
        </div>
      )}
    </section>
  )
}

interface ImportFormProps {
  onImported: (result: CourseImportResult) => void
}

/** 弹窗内容：随 open 挂载销毁，每次打开重置为初始态 */
function ImportForm({ onImported }: ImportFormProps) {
  const [file, setFile] = useState<File | null>(null)
  const [fileError, setFileError] = useState('')
  const [dragging, setDragging] = useState(false)
  const [uploading, setUploading] = useState(false)
  const [result, setResult] = useState<CourseImportResult | null>(null)
  const [failure, setFailure] = useState<ImportFailure | null>(null)
  const push = useToast()

  const handlePick = useCallback((picked: File | undefined) => {
    if (!picked) return
    if (!picked.name.toLowerCase().endsWith('.zip')) {
      setFileError('仅支持 .zip 格式的课程包')
      return
    }
    setFile(picked)
    setFileError('')
    setResult(null)
    setFailure(null)
  }, [])

  const handleClear = useCallback(() => {
    setFile(null)
    setFileError('')
  }, [])

  const handleImport = useCallback(async () => {
    if (!file || uploading) return
    setUploading(true)
    setResult(null)
    setFailure(null)
    try {
      const data = await importCoursePackage(file)
      setResult(data)
      // 成功 toast 与列表刷新由调用方（课程页）在 onImported 中处理
      onImported(data)
    } catch (e) {
      const next: ImportFailure =
        e instanceof ApiError ? { code: e.code, message: e.message } : { code: 'UNKNOWN', message: errMsg(e) }
      setFailure(next)
      push('error', `导入失败：${next.message}`)
    } finally {
      setUploading(false)
    }
  }, [file, uploading, push, onImported])

  return (
    <div className="flex flex-col gap-4">
      <UploadCard
        file={file}
        fileError={fileError}
        dragging={dragging}
        uploading={uploading}
        onPick={handlePick}
        onDraggingChange={setDragging}
        onImport={() => void handleImport()}
        onClear={handleClear}
      />
      <ResultCard result={result} failure={failure} uploading={uploading} />
    </div>
  )
}

interface CourseImportDialogProps {
  open: boolean
  onClose: () => void
  /** 导入成功回调（调用方负责 toast 与列表刷新） */
  onImported: (result: CourseImportResult) => void
}

/** 课程导入弹窗：内嵌上传卡 + 结果卡，open=false 时不渲染内容以重置内部状态 */
export function CourseImportDialog({ open, onClose, onImported }: CourseImportDialogProps) {
  return (
    <Modal open={open} title="导入课程包" onClose={onClose} size="lg">
      {open ? <ImportForm onImported={onImported} /> : null}
    </Modal>
  )
}
