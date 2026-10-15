import { useState, type FormEvent } from 'react'
import type { Course, CourseInput } from '../api/types'
import { SLUG_ERROR, SLUG_RE } from '../lib/validate'
import { Field, btnGhost, btnPrimary, inputCls } from './ui'

const LANG_SUGGESTIONS = ['Go', 'Python', 'Rust', 'JavaScript', 'TypeScript', 'Java', 'C++']

interface FormState {
  slug: string
  title: string
  summary: string
  language: string
  color: string
  sort_order: string
}

type FormErrors = Partial<Record<keyof FormState, string>>

function toFormState(c: Course | null | undefined): FormState {
  return {
    slug: c?.slug ?? '',
    title: c?.title ?? '',
    summary: c?.summary ?? '',
    language: c?.language ?? '',
    color: c?.color || '#0D9488',
    sort_order: String(c?.sort_order ?? 0),
  }
}

interface CourseFormProps {
  /** 传入则为编辑模式（slug 锁定） */
  initial?: Course | null
  submitting: boolean
  submitLabel: string
  onSubmit: (input: CourseInput) => void
  onCancel: () => void
}

export function CourseForm({ initial, submitting, submitLabel, onSubmit, onCancel }: CourseFormProps) {
  const [form, setForm] = useState<FormState>(() => toFormState(initial))
  const [errors, setErrors] = useState<FormErrors>({})

  const set = (key: keyof FormState, value: string) => {
    setForm((prev) => ({ ...prev, [key]: value }))
    setErrors((prev) => (prev[key] ? { ...prev, [key]: undefined } : prev))
  }

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault()
    const next: FormErrors = {}
    if (!SLUG_RE.test(form.slug.trim())) next.slug = SLUG_ERROR
    if (!form.title.trim()) next.title = '请输入标题'
    setErrors(next)
    if (next.slug || next.title) return
    onSubmit({
      slug: form.slug.trim(),
      title: form.title.trim(),
      summary: form.summary.trim(),
      language: form.language.trim(),
      color: form.color,
      sort_order: Number.parseInt(form.sort_order, 10) || 0,
    })
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-3" noValidate>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <Field label="课程 Slug" error={errors.slug} hint="URL 标识，创建后不可修改">
          <input
            className={`${inputCls} font-mono`}
            value={form.slug}
            onChange={(e) => set('slug', e.target.value)}
            placeholder="go-basics"
            disabled={submitting || Boolean(initial)}
          />
        </Field>
        <Field label="课程标题" error={errors.title}>
          <input
            className={inputCls}
            value={form.title}
            onChange={(e) => set('title', e.target.value)}
            placeholder="例如：Go 语言入门"
            disabled={submitting}
          />
        </Field>
      </div>

      <Field label="课程简介">
        <textarea
          className={`${inputCls} h-auto resize-none py-2`}
          rows={3}
          value={form.summary}
          onChange={(e) => set('summary', e.target.value)}
          placeholder="一句话介绍这门课"
          disabled={submitting}
        />
      </Field>

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <Field label="语言" hint="如 Go / Python">
          <input
            className={inputCls}
            list="course-language-options"
            value={form.language}
            onChange={(e) => set('language', e.target.value)}
            placeholder="Go"
            disabled={submitting}
          />
          <datalist id="course-language-options">
            {LANG_SUGGESTIONS.map((lang) => (
              <option key={lang} value={lang} />
            ))}
          </datalist>
        </Field>
        <Field label="主题色">
          <div className="flex items-center gap-2">
            <input
              type="color"
              aria-label="选择颜色"
              className="h-9 w-12 cursor-pointer rounded-lg border border-track bg-white p-1"
              value={form.color}
              onChange={(e) => set('color', e.target.value)}
              disabled={submitting}
            />
            <input
              className={`${inputCls} font-mono`}
              value={form.color}
              onChange={(e) => set('color', e.target.value)}
              disabled={submitting}
            />
          </div>
        </Field>
        <Field label="排序" hint="数字越小越靠前">
          <input
            type="number"
            className={inputCls}
            value={form.sort_order}
            onChange={(e) => set('sort_order', e.target.value)}
            disabled={submitting}
          />
        </Field>
      </div>

      <div className="mt-2 flex justify-end gap-2">
        <button type="button" className={btnGhost} onClick={onCancel} disabled={submitting}>
          取消
        </button>
        <button type="submit" className={btnPrimary} disabled={submitting}>
          {submitting ? '提交中…' : submitLabel}
        </button>
      </div>
    </form>
  )
}
