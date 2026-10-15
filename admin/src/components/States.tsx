import type { ReactNode } from 'react'

/** 加载 / 错误 / 空态三种占位块，均为卡片样式 */

export function LoadingBlock({ text = '加载中…' }: { text?: string }) {
  return (
    <div className="flex items-center justify-center gap-2.5 rounded-card border border-track bg-card py-16 text-sm text-inkmuted">
      <span className="h-4 w-4 animate-spin rounded-full border-2 border-accent border-t-transparent" aria-hidden />
      {text}
    </div>
  )
}

export function ErrorBlock({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div className="rounded-card border border-red-200 bg-red-50/60 py-12 text-center">
      <p className="text-sm font-medium text-red-700">加载失败：{message}</p>
      {onRetry && (
        <button
          type="button"
          onClick={onRetry}
          className="mt-3 inline-flex h-9 items-center rounded-full border border-red-300 bg-white px-4 text-sm font-medium text-red-700 transition hover:bg-red-50"
        >
          重试
        </button>
      )}
    </div>
  )
}

interface EmptyBlockProps {
  title: string
  hint?: string
  action?: ReactNode
}

export function EmptyBlock({ title, hint, action }: EmptyBlockProps) {
  return (
    <div className="rounded-card border border-dashed border-track bg-card py-16 text-center">
      <p className="text-base font-bold text-ink">{title}</p>
      {hint && <p className="mt-1.5 text-[13px] text-inkmuted">{hint}</p>}
      {action && <div className="mt-4 flex justify-center">{action}</div>}
    </div>
  )
}
