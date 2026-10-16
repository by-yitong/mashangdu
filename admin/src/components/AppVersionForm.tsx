import { useState, type FormEvent } from 'react'
import type { AppVersion, AppVersionCreateInput } from '../api/types'
import { Field, btnGhost, btnPrimary, inputCls } from './ui'

interface FormState {
  version: string
  versionCode: string
  notes: string
  apkUrl: string
  force: boolean
  enabled: boolean
}

type FormErrors = Partial<Record<'version' | 'versionCode' | 'apkUrl', string>>

function toFormState(v: AppVersion | null | undefined): FormState {
  return {
    version: v?.version ?? '',
    versionCode: v ? String(v.versionCode) : '',
    notes: v?.notes ?? '',
    apkUrl: v?.apkUrl ?? '',
    force: v?.force ?? false,
    enabled: v?.enabled ?? true,
  }
}

interface AppVersionFormProps {
  /** 传入则为编辑模式（额外提供 enabled 勾选） */
  initial?: AppVersion | null
  submitting: boolean
  submitLabel: string
  /** enabled 仅编辑模式使用（POST 契约不含该字段） */
  onSubmit: (input: AppVersionCreateInput, enabled: boolean) => void
  onCancel: () => void
}

function CheckRow({
  checked,
  label,
  hint,
  disabled,
  onToggle,
}: {
  checked: boolean
  label: string
  hint: string
  disabled: boolean
  onToggle: (v: boolean) => void
}) {
  return (
    <label className="flex cursor-pointer select-none items-center gap-2">
      <input
        type="checkbox"
        className="h-4 w-4 accent-accent"
        checked={checked}
        onChange={(e) => onToggle(e.target.checked)}
        disabled={disabled}
      />
      <span className="text-[13px] font-medium text-ink">{label}</span>
      <span className="text-xs text-inkmuted">{hint}</span>
    </label>
  )
}

export function AppVersionForm({ initial, submitting, submitLabel, onSubmit, onCancel }: AppVersionFormProps) {
  const [form, setForm] = useState<FormState>(() => toFormState(initial))
  const [errors, setErrors] = useState<FormErrors>({})
  const editing = Boolean(initial)

  const setField = <K extends keyof FormState>(key: K, value: FormState[K]) => {
    setForm((prev) => ({ ...prev, [key]: value }))
    setErrors((prev) => (prev[key as keyof FormErrors] ? { ...prev, [key]: undefined } : prev))
  }

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault()
    const versionCode = Number.parseInt(form.versionCode, 10)
    const next: FormErrors = {}
    if (!form.version.trim()) next.version = '请输入版本号'
    if (!form.apkUrl.trim()) next.apkUrl = '请输入 APK 下载地址'
    if (!/^\d+$/.test(form.versionCode.trim()) || !Number.isFinite(versionCode) || versionCode <= 0) {
      next.versionCode = '必须为大于 0 的整数'
    }
    setErrors(next)
    if (next.version || next.versionCode || next.apkUrl) return
    onSubmit(
      {
        version: form.version.trim(),
        versionCode,
        notes: form.notes.trim(),
        apkUrl: form.apkUrl.trim(),
        force: form.force,
      },
      form.enabled,
    )
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-3" noValidate>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <Field label="版本号" error={errors.version}>
          <input
            className={`${inputCls} font-mono`}
            value={form.version}
            onChange={(e) => setField('version', e.target.value)}
            placeholder="1.2.0"
            disabled={submitting}
          />
        </Field>
        <Field label="versionCode" error={errors.versionCode} hint="递增整数，客户端据此判断升级">
          <input
            type="number"
            min={1}
            step={1}
            className={`${inputCls} font-mono`}
            value={form.versionCode}
            onChange={(e) => setField('versionCode', e.target.value)}
            placeholder="120"
            disabled={submitting}
          />
        </Field>
      </div>

      <Field label="APK 下载地址" error={errors.apkUrl}>
        <input
          className={`${inputCls} font-mono`}
          value={form.apkUrl}
          onChange={(e) => setField('apkUrl', e.target.value)}
          placeholder="https://example.com/app-release-1.2.0.apk"
          disabled={submitting}
        />
      </Field>

      <Field label="更新说明">
        <textarea
          className={`${inputCls} h-auto resize-none py-2`}
          rows={3}
          value={form.notes}
          onChange={(e) => setField('notes', e.target.value)}
          placeholder="本次更新内容…"
          disabled={submitting}
        />
      </Field>

      <div className="flex flex-col gap-2">
        <span className="block text-[13px] font-medium text-ink">更新策略</span>
        <div className="flex flex-wrap items-center gap-x-6 gap-y-2">
          <CheckRow
            checked={form.force}
            label="强制更新"
            hint="低于此版本必须升级"
            disabled={submitting}
            onToggle={(v) => setField('force', v)}
          />
          {editing && (
            <CheckRow
              checked={form.enabled}
              label="启用此版本"
              hint="停用后客户端不检查到该版本"
              disabled={submitting}
              onToggle={(v) => setField('enabled', v)}
            />
          )}
        </div>
        {!editing && <span className="block text-xs text-inkmuted">新建版本默认启用，创建后可在编辑中停用</span>}
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
