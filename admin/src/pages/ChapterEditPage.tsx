import { memo, useCallback, useEffect, useMemo, useRef, useState, type RefObject } from 'react'
import ReactMarkdown from 'react-markdown'
import { Link, useBlocker, useNavigate, useParams } from 'react-router-dom'
import remarkGfm from 'remark-gfm'
import { api, errMsg } from '../api/client'
import type { ChapterDetail, ChapterInput } from '../api/types'
import { ErrorBlock, LoadingBlock } from '../components/States'
import { Field, btnGhost, btnPrimary, inputCls } from '../components/ui'
import { fmtTime } from '../lib/format'
import { insertSnippet, useDebouncedValue, type SnippetKind } from '../lib/markdown'
import { SLUG_ERROR, SLUG_RE } from '../lib/validate'
import { useToast } from '../ToastProvider'

type Status = 'loading' | 'ready' | 'error'

interface FormState {
  title: string
  slug: string
  sort_order: string
  content_md: string
}

const EMPTY_FORM: FormState = { title: '', slug: '', sort_order: '0', content_md: '' }

const TOOLS: { kind: SnippetKind; label: string; title: string }[] = [
  { kind: 'heading', label: 'H2 标题', title: '在行首插入二级标题' },
  { kind: 'bold', label: 'B 加粗', title: '加粗选中文本' },
  { kind: 'inlineCode', label: '行内代码', title: '行内代码' },
  { kind: 'codeBlock', label: '代码块', title: '插入代码块' },
  { kind: 'list', label: '• 列表', title: '无序列表' },
  { kind: 'orderedList', label: '1. 列表', title: '有序列表' },
  { kind: 'link', label: '链接', title: '插入链接' },
]

const MarkdownPreview = memo(function MarkdownPreview({ content }: { content: string }) {
  if (!content.trim()) {
    return <p className="text-[13px] text-inkmuted">暂无内容，在左侧输入 Markdown 即可实时预览。</p>
  }
  return (
    <div className="preview prose prose-sm max-w-none">
      <ReactMarkdown remarkPlugins={[remarkGfm]}>{content}</ReactMarkdown>
    </div>
  )
})

/**
 * 未保存变更离开拦截：
 * - 站内路由跳转用 useBlocker（data router）
 * - 刷新/关闭标签页用 beforeunload
 */
function useUnsavedGuard(dirty: boolean, isDirtyRef: RefObject<boolean>) {
  const blocker = useBlocker(({ currentLocation, nextLocation }) => {
    return Boolean(isDirtyRef.current) && currentLocation.pathname !== nextLocation.pathname
  })

  useEffect(() => {
    if (blocker.state !== 'blocked') return
    const leave = window.confirm('当前章节有未保存的更改，离开将丢失。确定离开吗？')
    if (leave) {
      blocker.proceed()
    } else {
      blocker.reset()
    }
  }, [blocker])

  useEffect(() => {
    if (!dirty) return
    const handler = (e: BeforeUnloadEvent) => {
      e.preventDefault()
      e.returnValue = ''
    }
    window.addEventListener('beforeunload', handler)
    return () => window.removeEventListener('beforeunload', handler)
  }, [dirty])
}

export function ChapterEditPage() {
  const { slug = '', chapterSlug } = useParams()
  const navigate = useNavigate()
  const push = useToast()
  const isEdit = Boolean(chapterSlug)

  const [status, setStatus] = useState<Status>(isEdit ? 'loading' : 'ready')
  const [loadError, setLoadError] = useState('')
  const [form, setForm] = useState<FormState>(EMPTY_FORM)
  const [savedSnapshot, setSavedSnapshot] = useState(() => JSON.stringify(EMPTY_FORM))
  const [saving, setSaving] = useState(false)
  const [fieldErrors, setFieldErrors] = useState<{ title?: string; slug?: string }>({})
  const [loadedAt, setLoadedAt] = useState<string | undefined>(undefined)
  const textareaRef = useRef<HTMLTextAreaElement | null>(null)

  const load = useCallback(async () => {
    if (!chapterSlug) return
    setStatus('loading')
    setLoadError('')
    try {
      const data = await api<ChapterDetail>(
        `/courses/${encodeURIComponent(slug)}/chapters/${encodeURIComponent(chapterSlug)}`,
      )
      const next: FormState = {
        title: data.title,
        slug: data.slug,
        sort_order: String(data.sort_order ?? data.order ?? 0),
        content_md: data.content_md ?? '',
      }
      setForm(next)
      setSavedSnapshot(JSON.stringify(next))
      setLoadedAt(data.updated_at)
      setStatus('ready')
    } catch (e) {
      setLoadError(errMsg(e))
      setStatus('error')
    }
  }, [slug, chapterSlug])

  useEffect(() => {
    void load()
  }, [load])

  const dirty = useMemo(() => JSON.stringify(form) !== savedSnapshot, [form, savedSnapshot])
  const dirtyRef = useRef(dirty)
  useEffect(() => {
    dirtyRef.current = dirty
  }, [dirty])
  useUnsavedGuard(dirty, dirtyRef)

  // 预览防抖 ≥300ms，输入保持流畅
  const debouncedContent = useDebouncedValue(form.content_md, 300)

  const patch = (partial: Partial<FormState>) => {
    setForm((prev) => ({ ...prev, ...partial }))
  }

  const clearFieldError = (key: 'title' | 'slug') => {
    setFieldErrors((prev) => (prev[key] ? { ...prev, [key]: undefined } : prev))
  }

  const applySnippet = useCallback((kind: SnippetKind) => {
    const textarea = textareaRef.current
    if (!textarea) return
    const result = insertSnippet(textarea.value, textarea.selectionStart, textarea.selectionEnd, kind)
    const value = result.text
    setForm((prev) => ({ ...prev, content_md: value }))
    window.requestAnimationFrame(() => {
      textarea.focus()
      textarea.setSelectionRange(result.selectionStart, result.selectionEnd)
    })
  }, [])

  const handleSave = async () => {
    const errors: { title?: string; slug?: string } = {}
    if (!form.title.trim()) errors.title = '请输入章节标题'
    if (!SLUG_RE.test(form.slug.trim())) errors.slug = SLUG_ERROR
    setFieldErrors(errors)
    if (errors.title || errors.slug) return

    const body: ChapterInput = {
      slug: form.slug.trim(),
      title: form.title.trim(),
      content_md: form.content_md,
      sort_order: Number.parseInt(form.sort_order, 10) || 0,
    }
    setSaving(true)
    try {
      if (isEdit) {
        await api(`/admin/courses/${encodeURIComponent(slug)}/chapters/${encodeURIComponent(chapterSlug ?? '')}`, {
          method: 'PUT',
          body,
        })
        push('success', '章节已保存')
      } else {
        await api(`/admin/courses/${encodeURIComponent(slug)}/chapters`, { method: 'POST', body })
        push('success', '章节已创建')
      }
      dirtyRef.current = false
      setSavedSnapshot(JSON.stringify(form))
      navigate(`/courses/${encodeURIComponent(slug)}`)
    } catch (e) {
      push('error', `保存失败：${errMsg(e)}`)
    } finally {
      setSaving(false)
    }
  }

  if (status === 'loading') {
    return <LoadingBlock text="加载章节内容…" />
  }
  if (status === 'error') {
    return (
      <div className="flex flex-col gap-4">
        <Link to={`/courses/${encodeURIComponent(slug)}`} className={`${btnGhost} self-start`}>
          ← 返回课程
        </Link>
        <ErrorBlock message={loadError} onRetry={() => void load()} />
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-4">
      {/* 顶栏：返回 / 标题 / 未保存标记 / 保存 */}
      <div className="flex flex-wrap items-center gap-3">
        <Link to={`/courses/${encodeURIComponent(slug)}`} className={btnGhost}>
          ← 返回课程
        </Link>
        <h1 className="text-lg font-bold text-ink">{isEdit ? '编辑章节' : '新建章节'}</h1>
        {dirty && (
          <span className="rounded-full bg-accentdim px-2.5 py-0.5 text-xs font-semibold text-accent">未保存</span>
        )}
        <div className="ml-auto flex items-center gap-2">
          {isEdit && loadedAt && (
            <span className="hidden font-mono text-xs text-inkmuted md:inline">
              上次更新 {fmtTime(loadedAt)}
            </span>
          )}
          <button
            type="button"
            className={btnPrimary}
            onClick={() => void handleSave()}
            disabled={saving || !dirty}
          >
            {saving ? '保存中…' : '保存章节'}
          </button>
        </div>
      </div>

      {/* 章节元信息 */}
      <section className="rounded-card border border-track bg-card p-4 shadow-sm">
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-4">
          <div className="sm:col-span-2">
            <Field label="章节标题" error={fieldErrors.title}>
              <input
                className={inputCls}
                value={form.title}
                onChange={(e) => {
                  patch({ title: e.target.value })
                  clearFieldError('title')
                }}
                placeholder="例如：Gin 路由与中间件"
                disabled={saving}
              />
            </Field>
          </div>
          <Field label="章节 Slug" error={fieldErrors.slug}>
            <input
              className={`${inputCls} font-mono`}
              value={form.slug}
              onChange={(e) => {
                patch({ slug: e.target.value })
                clearFieldError('slug')
              }}
              placeholder="gin-routing"
              spellCheck={false}
              disabled={saving}
            />
          </Field>
          <Field label="排序" hint="数字越小越靠前">
            <input
              type="number"
              className={inputCls}
              value={form.sort_order}
              onChange={(e) => patch({ sort_order: e.target.value })}
              disabled={saving}
            />
          </Field>
        </div>
      </section>

      {/* 左编辑右预览 */}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <section className="flex min-h-130 flex-col rounded-card border border-track bg-card p-3 shadow-sm">
          <div className="mb-2 flex flex-wrap items-center gap-1 border-b border-track pb-2">
            {TOOLS.map((tool) => (
              <button
                key={tool.kind}
                type="button"
                title={tool.title}
                onClick={() => applySnippet(tool.kind)}
                className="rounded-md px-2 py-1 text-xs font-medium text-inkmuted transition hover:bg-track/60 hover:text-ink"
              >
                {tool.label}
              </button>
            ))}
            <span className="ml-auto pr-1 font-mono text-[11px] text-inkmuted">
              {form.content_md.length} 字符
            </span>
          </div>
          <textarea
            ref={textareaRef}
            value={form.content_md}
            onChange={(e) => patch({ content_md: e.target.value })}
            spellCheck={false}
            placeholder={'在此输入 Markdown 内容…\n\n# 一级标题\n\n```go\nfmt.Println("hello")\n```'}
            className="min-h-0 flex-1 resize-none bg-transparent p-2 font-mono text-[13px] leading-relaxed text-ink outline-none placeholder:text-inkmuted/50"
          />
        </section>

        <section className="min-h-130 overflow-y-auto rounded-card border border-track bg-card p-5 shadow-sm">
          <div className="mb-3 border-b border-track pb-2 text-xs font-semibold tracking-wide text-inkmuted">
            实时预览（防抖 300ms）
          </div>
          <MarkdownPreview content={debouncedContent} />
        </section>
      </div>
    </div>
  )
}
