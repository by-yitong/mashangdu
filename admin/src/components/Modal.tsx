import { Dialog as DialogPrimitive } from 'radix-ui'
import type { ReactNode } from 'react'
import { btnDangerSolid, btnGhost } from './ui'

type ModalSize = 'md' | 'lg'

/** 尺寸 → 内容区最大宽度（md 为历史默认） */
const SIZE_CLS: Record<ModalSize, string> = {
  md: 'max-w-lg',
  lg: 'max-w-2xl',
}

interface ModalProps {
  open: boolean
  title: string
  onClose: () => void
  children: ReactNode
  /** 内容区最大宽度，默认 md（max-w-lg） */
  size?: ModalSize
  /** 内部使用：true 时阻断 ESC/点遮罩/关闭按钮（ConfirmDialog loading 态） */
  lockClose?: boolean
}

/**
 * radix Dialog 封装：ESC/点遮罩/关闭按钮均回调 onClose；锁定 body 滚动与焦点圈定由 radix 自带。
 * 与旧版差异：内容固定定位（top-4/sm:top-16），超高时内容区自身滚动。
 */
export function Modal({ open, title, onClose, children, size = 'md', lockClose = false }: ModalProps) {
  return (
    <DialogPrimitive.Root
      open={open}
      onOpenChange={(next) => {
        if (!next && !lockClose) onClose()
      }}
    >
      <DialogPrimitive.Portal>
        <DialogPrimitive.Overlay className="fixed inset-0 z-50 bg-black/40" />
        <DialogPrimitive.Content
          className={`fixed left-1/2 top-4 z-50 max-h-[calc(100vh-2rem)] w-[calc(100%-2rem)] -translate-x-1/2 overflow-y-auto rounded-card border border-track bg-card p-5 shadow-lg sm:top-16 sm:max-h-[calc(100vh-8rem)] ${SIZE_CLS[size]}`}
          onEscapeKeyDown={(e) => {
            if (lockClose) e.preventDefault()
          }}
          onInteractOutside={(e) => {
            if (lockClose) e.preventDefault()
          }}
        >
          <div className="mb-4 flex items-center justify-between">
            <DialogPrimitive.Title className="text-lg font-bold text-ink">{title}</DialogPrimitive.Title>
            <DialogPrimitive.Close
              aria-label="关闭"
              disabled={lockClose}
              className="rounded-full p-1.5 text-inkmuted transition hover:bg-track/60 hover:text-ink disabled:cursor-not-allowed disabled:opacity-40"
            >
              <svg viewBox="0 0 20 20" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M5 5l10 10M15 5L5 15" strokeLinecap="round" />
              </svg>
            </DialogPrimitive.Close>
          </div>
          {children}
        </DialogPrimitive.Content>
      </DialogPrimitive.Portal>
    </DialogPrimitive.Root>
  )
}

interface ConfirmDialogProps {
  open: boolean
  title: string
  message: string
  loading?: boolean
  onConfirm: () => void
  onCancel: () => void
}

/** 确认弹窗：loading 时阻断一切关闭途径（ESC/遮罩/关闭按钮 + 取消按钮禁用） */
export function ConfirmDialog({ open, title, message, loading, onConfirm, onCancel }: ConfirmDialogProps) {
  return (
    <Modal open={open} title={title} onClose={onCancel} lockClose={loading}>
      <DialogPrimitive.Description className="text-sm leading-relaxed text-inkmuted">
        {message}
      </DialogPrimitive.Description>
      <div className="mt-5 flex justify-end gap-2">
        <button type="button" className={btnGhost} onClick={onCancel} disabled={loading}>
          取消
        </button>
        <button type="button" className={btnDangerSolid} onClick={onConfirm} disabled={loading}>
          {loading ? '删除中…' : '确认删除'}
        </button>
      </div>
    </Modal>
  )
}
