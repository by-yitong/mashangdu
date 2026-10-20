import { memo, useCallback, useEffect, useRef, useState, type ChangeEvent } from 'react'
import { DropdownMenu as DropdownMenuPrimitive } from 'radix-ui'
import { ApiError, deleteUser, errMsg, listUsers } from '../api/client'
import type { AdminUser, AdminUserPage } from '../api/types'
import { Avatar } from '../components/Avatar'
import { ConfirmDialog } from '../components/Modal'
import { EmptyBlock, ErrorBlock, LoadingBlock } from '../components/States'
import { btnGhost, inputCls } from '../components/ui'
import { fmtTime, formatInt } from '../lib/format'
import { useToast } from '../ToastProvider'

type Status = 'loading' | 'ready' | 'error'

/** 固定每页条数（total/page/pageCount 以接口返回为准） */
const PAGE_SIZE = 20

/** 搜索防抖等待时间（ms） */
const SEARCH_DEBOUNCE_MS = 300

interface UserRowProps {
  user: AdminUser
  onDelete: (user: AdminUser) => void
}

/** 表格行：memo 隔离重渲染；操作列为 radix DropdownMenu */
const UserRow = memo(function UserRow({ user, onDelete }: UserRowProps) {
  const handleDeleteSelect = useCallback(() => onDelete(user), [user, onDelete])

  return (
    <tr className="border-b border-track/60 align-middle transition last:border-0 hover:bg-paper/70">
      <td className="px-4 py-3">
        <div className="flex items-center gap-3">
          <Avatar username={user.username} avatar={user.avatar} />
          <p className="font-medium text-ink">{user.username}</p>
        </div>
      </td>
      <td className="whitespace-nowrap px-4 py-3 text-[13px] text-inkmuted">{fmtTime(user.createdAt)}</td>
      <td className="whitespace-nowrap px-4 py-3 text-[13px] text-ink">{formatInt(user.commentCount)}</td>
      <td className="whitespace-nowrap px-4 py-3 text-[13px] text-ink">{formatInt(user.likeCount)}</td>
      <td className="whitespace-nowrap px-4 py-3 text-[13px] text-ink">{formatInt(user.recordCount)}</td>
      <td className="whitespace-nowrap px-4 py-3 text-[13px] text-inkmuted">
        {user.lastReadAt ? fmtTime(user.lastReadAt) : '—'}
      </td>
      <td className="whitespace-nowrap px-4 py-3 text-right">
        <DropdownMenuPrimitive.Root>
          <DropdownMenuPrimitive.Trigger
            aria-label="用户操作"
            className="inline-flex h-8 w-8 items-center justify-center rounded-full text-inkmuted transition hover:bg-track/60 hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/40"
          >
            <svg viewBox="0 0 16 16" className="h-4 w-4" fill="currentColor" aria-hidden>
              <circle cx="3" cy="8" r="1.4" />
              <circle cx="8" cy="8" r="1.4" />
              <circle cx="13" cy="8" r="1.4" />
            </svg>
          </DropdownMenuPrimitive.Trigger>
          <DropdownMenuPrimitive.Portal>
            <DropdownMenuPrimitive.Content
              align="end"
              sideOffset={4}
              className="z-50 min-w-36 rounded-xl border border-track bg-card p-1 shadow-lg"
            >
              <DropdownMenuPrimitive.Item
                className="cursor-pointer rounded-lg px-3 py-2 text-sm text-red-600 outline-none transition data-[highlighted]:bg-red-50"
                onSelect={handleDeleteSelect}
              >
                删除用户
              </DropdownMenuPrimitive.Item>
            </DropdownMenuPrimitive.Content>
          </DropdownMenuPrimitive.Portal>
        </DropdownMenuPrimitive.Root>
      </td>
    </tr>
  )
})

interface PageNavProps {
  page: number
  pageCount: number
  disabled: boolean
  onChange: (page: number) => void
}

/** 分页控件：上一页/下一页 + 页码描述（样式与评论管理一致） */
const PageNav = memo(function PageNav({ page, pageCount, disabled, onChange }: PageNavProps) {
  const handlePrev = useCallback(() => onChange(page - 1), [page, onChange])
  const handleNext = useCallback(() => onChange(page + 1), [page, onChange])

  return (
    <nav className="flex flex-wrap items-center justify-between gap-3 border-t border-track px-4 py-3" aria-label="分页">
      <p className="text-xs text-inkmuted">
        第 {page} / {pageCount} 页
      </p>
      <div className="flex items-center gap-1.5">
        <button
          type="button"
          className={`${btnGhost} h-8 px-3`}
          disabled={disabled || page <= 1}
          onClick={handlePrev}
        >
          上一页
        </button>
        <button
          type="button"
          className={`${btnGhost} h-8 px-3`}
          disabled={disabled || page >= pageCount}
          onClick={handleNext}
        >
          下一页
        </button>
      </div>
    </nav>
  )
})

export function UserListPage() {
  const [status, setStatus] = useState<Status>('loading')
  const [data, setData] = useState<AdminUserPage | null>(null)
  const [loadError, setLoadError] = useState('')
  /** 输入框即时值 */
  const [qInput, setQInput] = useState('')
  /** 实际发起请求的搜索词（防抖后同步） */
  const [q, setQ] = useState('')
  const [page, setPage] = useState(1)
  const [pendingDelete, setPendingDelete] = useState<AdminUser | null>(null)
  const [deleting, setDeleting] = useState(false)
  const push = useToast()
  /** 请求序号：搜索/翻页快速切换时丢弃过期响应 */
  const reqIdRef = useRef(0)
  /** 防抖 timer 存 ref，卸载时清理 */
  const debounceRef = useRef<number | undefined>(undefined)

  const load = useCallback(async () => {
    const reqId = (reqIdRef.current += 1)
    setStatus('loading')
    setLoadError('')
    try {
      const result = await listUsers({ page, pageSize: PAGE_SIZE, q: q || undefined })
      if (reqIdRef.current !== reqId) return
      setData(result)
      setStatus('ready')
    } catch (e) {
      if (reqIdRef.current !== reqId) return
      setLoadError(errMsg(e))
      setStatus('error')
    }
  }, [q, page])

  useEffect(() => {
    void load()
  }, [load])

  // 组件卸载时清掉未触发的防抖 timer，避免泄漏后 setState
  useEffect(() => {
    return () => window.clearTimeout(debounceRef.current)
  }, [])

  /** 搜索防抖：输入停止 300ms 后才请求，并重置回第 1 页 */
  const handleSearchChange = useCallback((e: ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value
    setQInput(value)
    window.clearTimeout(debounceRef.current)
    debounceRef.current = window.setTimeout(() => {
      setQ(value.trim())
      setPage(1)
    }, SEARCH_DEBOUNCE_MS)
  }, [])

  const handlePageChange = useCallback((next: number) => {
    setPage(next)
  }, [])

  const handleDeleteClick = useCallback((user: AdminUser) => {
    setPendingDelete(user)
  }, [])

  const handleDelete = async () => {
    if (!pendingDelete) return
    setDeleting(true)
    try {
      await deleteUser(pendingDelete.id)
      push('success', `已删除用户「${pendingDelete.username}」`)
      setPendingDelete(null)
      // 当前页只剩这一条且不是首页：回退一页，由 effect 触发重新加载
      if ((data?.users.length ?? 0) <= 1 && page > 1) {
        setPage(page - 1)
      } else {
        await load()
      }
    } catch (e) {
      push('error', `删除失败：${errMsg(e)}`)
      // 用户已被删除（404）：关掉弹窗并刷新，避免对不存在的书签式条目重复操作
      if (e instanceof ApiError && e.status === 404) {
        setPendingDelete(null)
        await load()
      }
    } finally {
      setDeleting(false)
    }
  }

  const total = data?.total ?? 0

  return (
    <div className="flex flex-col gap-5">
      <div>
        <h1 className="text-[32px] font-bold leading-tight text-ink">用户管理</h1>
        <p className="mt-1 text-[13px] text-inkmuted">
          {status === 'ready' && data ? `共 ${formatInt(total)} 位用户` : '正在同步用户数据'}
        </p>
      </div>

      {/* 工具行：用户名搜索（防抖） */}
      <section className="flex flex-wrap items-center justify-between gap-3 rounded-card border border-track bg-card px-4 py-3 shadow-sm">
        <input
          type="search"
          value={qInput}
          onChange={handleSearchChange}
          placeholder="搜索用户名"
          aria-label="搜索用户名"
          className={`${inputCls} sm:w-64`}
        />
      </section>

      {status === 'loading' && <LoadingBlock text="加载用户列表…" />}
      {status === 'error' && <ErrorBlock message={loadError} onRetry={() => void load()} />}
      {status === 'ready' && data &&
        (data.users.length === 0 ? (
          <EmptyBlock
            title="还没有用户"
            hint={q ? '未找到匹配的用户，试试更换关键词' : '学员注册后会展示在这里'}
          />
        ) : (
          <section className="rounded-card border border-track bg-card shadow-sm">
            <div className="overflow-x-auto">
              <table className="w-full min-w-[760px] text-left text-sm">
                <thead>
                  <tr className="border-b border-track text-xs text-inkmuted">
                    <th className="px-4 py-3 font-medium">用户</th>
                    <th className="px-4 py-3 font-medium">注册时间</th>
                    <th className="px-4 py-3 font-medium">评论数</th>
                    <th className="px-4 py-3 font-medium">点赞数</th>
                    <th className="px-4 py-3 font-medium">阅读记录</th>
                    <th className="px-4 py-3 font-medium">最近阅读</th>
                    <th className="px-4 py-3 text-right font-medium">操作</th>
                  </tr>
                </thead>
                <tbody>
                  {data.users.map((user) => (
                    <UserRow key={user.id} user={user} onDelete={handleDeleteClick} />
                  ))}
                </tbody>
              </table>
            </div>
            <PageNav
              page={data.page || page}
              pageCount={data.pageCount}
              disabled={status !== 'ready'}
              onChange={handlePageChange}
            />
          </section>
        ))}

      <ConfirmDialog
        open={pendingDelete !== null}
        title="删除用户"
        message={`确定删除用户「${pendingDelete?.username ?? ''}」吗？该用户的评论、点赞与阅读记录将一并清除，不可恢复。`}
        loading={deleting}
        onConfirm={() => void handleDelete()}
        onCancel={() => setPendingDelete(null)}
      />
    </div>
  )
}
