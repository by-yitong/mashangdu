import { memo, useCallback, useEffect, useMemo, useRef, useState, type ChangeEvent } from 'react'
import { api, deleteComment, errMsg, listComments } from '../api/client'
import type { AdminComment, AdminCommentPage, Course } from '../api/types'
import { ConfirmDialog } from '../components/Modal'
import { EmptyBlock, ErrorBlock, LoadingBlock } from '../components/States'
import { btnDangerGhost, btnGhost } from '../components/ui'
import { fmtTime } from '../lib/format'
import { useToast } from '../ToastProvider'

type Status = 'loading' | 'ready' | 'error'

/** 固定每页条数（total/page/pageCount 以接口返回为准） */
const PAGE_SIZE = 20

/** 内容超过该长度才显示「展开/收起」 */
const CONTENT_CLAMP_LEN = 60

const selectCls =
  'h-9 rounded-lg border border-track bg-white px-3 text-sm text-ink outline-none transition focus:border-accent focus:ring-2 focus:ring-accent/20 disabled:cursor-not-allowed disabled:opacity-60'

/** 生成分页页码序列（超过 7 页时折叠中间页码） */
function buildPageItems(page: number, pageCount: number): Array<number | '…'> {
  if (pageCount <= 7) return Array.from({ length: pageCount }, (_, i) => i + 1)
  const items: Array<number | '…'> = [1]
  const start = Math.max(2, page - 1)
  const end = Math.min(pageCount - 1, page + 1)
  if (start > 2) items.push('…')
  for (let p = start; p <= end; p += 1) items.push(p)
  if (end < pageCount - 1) items.push('…')
  items.push(pageCount)
  return items
}

interface CommentRowProps {
  comment: AdminComment
  onDelete: (comment: AdminComment) => void
}

/** 表格行：memo 隔离重渲染，展开状态收敛在行内 */
const CommentRow = memo(function CommentRow({ comment, onDelete }: CommentRowProps) {
  const [expanded, setExpanded] = useState(false)
  const toggleExpanded = useCallback(() => setExpanded((v) => !v), [])
  const handleDelete = useCallback(() => onDelete(comment), [comment, onDelete])
  const clamped = comment.content.length > CONTENT_CLAMP_LEN

  return (
    <tr className="border-b border-track/60 align-middle transition last:border-0 hover:bg-paper/70">
      <td className="whitespace-nowrap px-4 py-3">
        <p className="font-medium text-ink">{comment.username}</p>
        <p className="mt-0.5 font-mono text-xs text-inkmuted">#{comment.userId}</p>
      </td>
      <td className="max-w-40 px-4 py-3">
        <p className="truncate text-[13px] text-ink" title={comment.courseTitle}>
          {comment.courseTitle}
        </p>
        <p className="mt-0.5 truncate font-mono text-xs text-inkmuted" title={comment.courseSlug}>
          {comment.courseSlug}
        </p>
      </td>
      <td className="max-w-40 px-4 py-3">
        <p className="truncate text-[13px] text-ink" title={comment.chapterTitle}>
          {comment.chapterTitle}
        </p>
        <p className="mt-0.5 truncate font-mono text-xs text-inkmuted" title={comment.chapterSlug}>
          {comment.chapterSlug}
        </p>
      </td>
      <td className="max-w-md px-4 py-3">
        <p
          className={
            expanded
              ? 'whitespace-pre-wrap text-[13px] leading-relaxed text-ink'
              : 'line-clamp-2 text-[13px] leading-relaxed text-ink'
          }
          title={expanded ? undefined : comment.content}
        >
          {comment.content}
        </p>
        {clamped && (
          <button
            type="button"
            className="mt-0.5 text-xs font-medium text-accent hover:underline"
            onClick={toggleExpanded}
          >
            {expanded ? '收起' : '展开'}
          </button>
        )}
      </td>
      <td className="whitespace-nowrap px-4 py-3 text-[13px] text-inkmuted">{fmtTime(comment.createdAt)}</td>
      <td className="whitespace-nowrap px-4 py-3 text-right">
        <button type="button" className={`${btnDangerGhost} h-8`} onClick={handleDelete}>
          删除
        </button>
      </td>
    </tr>
  )
})

interface PageNavProps {
  page: number
  pageCount: number
  total: number
  disabled: boolean
  onChange: (page: number) => void
}

/** 分页控件：卡片底部工具条（页码序列 useMemo 派生） */
const PageNav = memo(function PageNav({ page, pageCount, total, disabled, onChange }: PageNavProps) {
  const items = useMemo(() => buildPageItems(page, pageCount), [page, pageCount])

  return (
    <nav className="flex flex-wrap items-center justify-between gap-3 border-t border-track px-4 py-3" aria-label="分页">
      <p className="text-xs text-inkmuted">
        共 {total} 条 · 第 {page}/{pageCount} 页
      </p>
      <div className="flex items-center gap-1.5">
        <button
          type="button"
          className={`${btnGhost} h-8 px-3`}
          disabled={disabled || page <= 1}
          onClick={() => onChange(page - 1)}
        >
          上一页
        </button>
        {items.map((item, idx) =>
          typeof item === 'number' ? (
            <button
              key={item}
              type="button"
              aria-current={item === page ? 'page' : undefined}
              className={`inline-flex h-8 min-w-8 items-center justify-center rounded-full px-2.5 text-[13px] font-medium transition disabled:cursor-not-allowed disabled:opacity-60 ${
                item === page
                  ? 'bg-accent/10 text-accent'
                  : 'border border-track bg-card text-inkmuted hover:bg-paper hover:text-ink'
              }`}
              disabled={disabled}
              onClick={() => onChange(item)}
            >
              {item}
            </button>
          ) : (
            <span key={`gap-${idx}`} className="px-1 text-xs text-inkmuted" aria-hidden>
              …
            </span>
          ),
        )}
        <button
          type="button"
          className={`${btnGhost} h-8 px-3`}
          disabled={disabled || page >= pageCount}
          onClick={() => onChange(page + 1)}
        >
          下一页
        </button>
      </div>
    </nav>
  )
})

export function CommentListPage() {
  const [status, setStatus] = useState<Status>('loading')
  const [data, setData] = useState<AdminCommentPage | null>(null)
  const [loadError, setLoadError] = useState('')
  const [courses, setCourses] = useState<Course[]>([])
  const [courseLoadFailed, setCourseLoadFailed] = useState(false)
  const [courseSlug, setCourseSlug] = useState('')
  const [page, setPage] = useState(1)
  const [pendingDelete, setPendingDelete] = useState<AdminComment | null>(null)
  const [deleting, setDeleting] = useState(false)
  const push = useToast()
  /** 请求序号：筛选/翻页快速切换时丢弃过期响应 */
  const reqIdRef = useRef(0)

  const load = useCallback(async () => {
    const reqId = (reqIdRef.current += 1)
    setStatus('loading')
    setLoadError('')
    try {
      const result = await listComments({
        courseSlug: courseSlug || undefined,
        page,
        pageSize: PAGE_SIZE,
      })
      if (reqIdRef.current !== reqId) return
      setData(result)
      setStatus('ready')
    } catch (e) {
      if (reqIdRef.current !== reqId) return
      setLoadError(errMsg(e))
      setStatus('error')
    }
  }, [courseSlug, page])

  useEffect(() => {
    void load()
  }, [load])

  /** 课程下拉选项：复用现有课程列表接口 */
  const loadCourses = useCallback(async () => {
    try {
      const result = await api<Course[]>('/courses')
      setCourses(result)
      setCourseLoadFailed(false)
    } catch {
      setCourseLoadFailed(true)
    }
  }, [])

  useEffect(() => {
    void loadCourses()
  }, [loadCourses])

  const courseOptions = useMemo(
    () =>
      [...courses]
        .sort((a, b) => a.sort_order - b.sort_order)
        .map((c) => ({ slug: c.slug, title: c.title })),
    [courses],
  )

  const handleCourseChange = useCallback((e: ChangeEvent<HTMLSelectElement>) => {
    setCourseSlug(e.target.value)
    setPage(1)
  }, [])

  const handlePageChange = useCallback((next: number) => {
    setPage(next)
  }, [])

  const handleRefresh = useCallback(() => {
    void load()
    void loadCourses()
  }, [load, loadCourses])

  const handleDeleteClick = useCallback((comment: AdminComment) => {
    setPendingDelete(comment)
  }, [])

  const handleDelete = async () => {
    if (!pendingDelete) return
    setDeleting(true)
    try {
      await deleteComment(pendingDelete.id)
      push('success', `已删除「${pendingDelete.username}」的评论`)
      setPendingDelete(null)
      // 当前页只剩这一条且不是首页：回退一页，由 effect 触发重新加载
      if ((data?.comments.length ?? 0) <= 1 && page > 1) {
        setPage(page - 1)
      } else {
        await load()
      }
    } catch (e) {
      push('error', `删除失败：${errMsg(e)}`)
    } finally {
      setDeleting(false)
    }
  }

  return (
    <div className="flex flex-col gap-5">
      <div>
        <h1 className="text-[32px] font-bold leading-tight text-ink">评论管理</h1>
        <p className="mt-1 text-[13px] text-inkmuted">
          {status === 'ready' && data ? `共 ${data.total} 条评论` : '正在同步评论数据'}
        </p>
      </div>

      {/* 筛选卡片 */}
      <section className="flex flex-wrap items-center justify-between gap-3 rounded-card border border-track bg-card px-4 py-3 shadow-sm">
        <div className="flex flex-wrap items-center gap-2.5">
          <label htmlFor="comment-course-filter" className="text-[13px] font-medium text-ink">
            课程
          </label>
          <select
            id="comment-course-filter"
            value={courseSlug}
            onChange={handleCourseChange}
            className={`${selectCls} w-52`}
            disabled={courseLoadFailed && courseOptions.length === 0}
          >
            <option value="">全部课程</option>
            {courseOptions.map((c) => (
              <option key={c.slug} value={c.slug}>
                {c.title}
              </option>
            ))}
          </select>
          {courseLoadFailed && <span className="text-xs text-inkmuted">课程选项加载失败，可点击刷新重试</span>}
        </div>
        <button type="button" className={btnGhost} onClick={handleRefresh} disabled={status === 'loading'}>
          刷新
        </button>
      </section>

      {status === 'loading' && <LoadingBlock text="加载评论列表…" />}
      {status === 'error' && <ErrorBlock message={loadError} onRetry={() => void load()} />}
      {status === 'ready' && data &&
        (data.comments.length === 0 ? (
          <EmptyBlock
            title={courseSlug ? '该课程暂无评论' : '暂无评论'}
            hint={courseSlug ? '试试切换其他课程，或点击刷新' : '学员在章节下留言后，会展示在这里'}
          />
        ) : (
          <section className="rounded-card border border-track bg-card shadow-sm">
            <div className="overflow-x-auto">
              <table className="w-full min-w-[960px] text-left text-sm">
                <thead>
                  <tr className="border-b border-track text-xs text-inkmuted">
                    <th className="px-4 py-3 font-medium">用户名</th>
                    <th className="px-4 py-3 font-medium">课程</th>
                    <th className="px-4 py-3 font-medium">章节</th>
                    <th className="px-4 py-3 font-medium">内容</th>
                    <th className="px-4 py-3 font-medium">时间</th>
                    <th className="px-4 py-3 text-right font-medium">操作</th>
                  </tr>
                </thead>
                <tbody>
                  {data.comments.map((c) => (
                    <CommentRow key={c.id} comment={c} onDelete={handleDeleteClick} />
                  ))}
                </tbody>
              </table>
            </div>
            <PageNav
              page={data.page || page}
              pageCount={data.pageCount}
              total={data.total}
              disabled={status !== 'ready'}
              onChange={handlePageChange}
            />
          </section>
        ))}

      <ConfirmDialog
        open={pendingDelete !== null}
        title="删除评论"
        message={`确定删除用户「${pendingDelete?.username ?? ''}」在「${pendingDelete?.chapterTitle ?? ''}」下的这条评论吗？此操作不可恢复。`}
        loading={deleting}
        onConfirm={() => void handleDelete()}
        onCancel={() => setPendingDelete(null)}
      />
    </div>
  )
}
