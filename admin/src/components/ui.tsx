import type { ReactNode } from 'react'

/** 共享样式常量（teal 主题、仪表盘卡片风） */

export const inputCls =
  'h-9 w-full rounded-lg border border-track bg-white px-3 text-sm text-ink placeholder:text-inkmuted/60 outline-none transition focus:border-accent focus:ring-2 focus:ring-accent/20 disabled:cursor-not-allowed disabled:opacity-60'

export const btnPrimary =
  'inline-flex h-9 items-center justify-center gap-1.5 rounded-full bg-accent px-4 text-sm font-medium text-white transition hover:bg-teal-700 disabled:cursor-not-allowed disabled:opacity-60'

export const btnGhost =
  'inline-flex h-9 items-center justify-center gap-1.5 rounded-full border border-track bg-card px-4 text-sm font-medium text-ink transition hover:border-inkmuted/40 hover:bg-paper disabled:cursor-not-allowed disabled:opacity-60'

export const btnDangerGhost =
  'inline-flex h-9 items-center justify-center gap-1.5 rounded-full border border-red-200 bg-card px-4 text-sm font-medium text-red-600 transition hover:bg-red-50 disabled:cursor-not-allowed disabled:opacity-60'

export const btnDangerSolid =
  'inline-flex h-9 items-center justify-center gap-1.5 rounded-full bg-red-600 px-4 text-sm font-medium text-white transition hover:bg-red-700 disabled:cursor-not-allowed disabled:opacity-60'

interface FieldProps {
  label: string
  hint?: string
  error?: string
  children: ReactNode
}

export function Field({ label, hint, error, children }: FieldProps) {
  return (
    <label className="block text-left">
      <span className="mb-1 block text-[13px] font-medium text-ink">{label}</span>
      {children}
      {error ? (
        <span className="mt-1 block text-xs text-red-600">{error}</span>
      ) : hint ? (
        <span className="mt-1 block text-xs text-inkmuted">{hint}</span>
      ) : null}
    </label>
  )
}
