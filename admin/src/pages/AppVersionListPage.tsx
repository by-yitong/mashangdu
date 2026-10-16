import { useCallback, useEffect, useState } from 'react'
import { api, errMsg } from '../api/client'
import type { AppVersion, AppVersionCreateInput, AppVersionUpdateInput } from '../api/types'
import { AppVersionForm } from '../components/AppVersionForm'
import { ConfirmDialog, Modal } from '../components/Modal'
import { EmptyBlock, ErrorBlock, LoadingBlock } from '../components/States'
import { btnDangerGhost, btnGhost, btnPrimary } from '../components/ui'
import { fmtTime } from '../lib/format'
import { useToast } from '../ToastProvider'

type Status = 'loading' | 'ready' | 'error'

function ForceBadge({ force }: { force: boolean }) {
  if (!force) return <span className="text-xs text-inkmuted">—</span>
  return (
    <span className="inline-flex items-center rounded-full border border-red-200 bg-red-50 px-2 py-0.5 text-xs font-medium text-red-700">
      强制
    </span>
  )
}

function EnabledBadge({ enabled }: { enabled: boolean }) {
  return enabled ? (
    <span className="inline-flex items-center rounded-full border border-teal-200 bg-teal-50 px-2 py-0.5 text-xs font-medium text-teal-700">
      已启用
    </span>
  ) : (
    <span className="inline-flex items-center rounded-full border border-track bg-paper px-2 py-0.5 text-xs font-medium text-inkmuted">
      已停用
    </span>
  )
}

export function AppVersionListPage() {
  const [status, setStatus] = useState<Status>('loading')
  const [versions, setVersions] = useState<AppVersion[]>([])
  const [loadError, setLoadError] = useState('')
  const [creating, setCreating] = useState(false)
  const [editing, setEditing] = useState<AppVersion | null>(null)
  const [submitting, setSubmitting] = useState(false)
  const [pendingDelete, setPendingDelete] = useState<AppVersion | null>(null)
  const [deleting, setDeleting] = useState(false)
  const push = useToast()

  const load = useCallback(async () => {
    setStatus('loading')
    setLoadError('')
    try {
      const data = await api<AppVersion[]>('/admin/app-versions')
      setVersions(data)
      setStatus('ready')
    } catch (e) {
      setLoadError(errMsg(e))
      setStatus('error')
    }
  }, [])

  useEffect(() => {
    void load()
  }, [load])

  const handleCreate = async (input: AppVersionCreateInput) => {
    setSubmitting(true)
    try {
      await api('/admin/app-versions', { method: 'POST', body: input })
      push('success', `版本「${input.version}」已创建`)
      setCreating(false)
      await load()
    } catch (e) {
      push('error', `创建失败：${errMsg(e)}`)
    } finally {
      setSubmitting(false)
    }
  }

  const handleUpdate = async (input: AppVersionUpdateInput) => {
    if (!editing) return
    setSubmitting(true)
    try {
      await api(`/admin/app-versions/${editing.id}`, { method: 'PUT', body: input })
      push('success', `版本「${input.version}」已更新`)
      setEditing(null)
      await load()
    } catch (e) {
      push('error', `更新失败：${errMsg(e)}`)
    } finally {
      setSubmitting(false)
    }
  }

  const handleDelete = async () => {
    if (!pendingDelete) return
    setDeleting(true)
    try {
      await api(`/admin/app-versions/${pendingDelete.id}`, { method: 'DELETE' })
      push('success', `版本「${pendingDelete.version}」已删除`)
      setPendingDelete(null)
      await load()
    } catch (e) {
      push('error', `删除失败：${errMsg(e)}`)
    } finally {
      setDeleting(false)
    }
  }

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-[32px] font-bold leading-tight text-ink">版本管理</h1>
          <p className="mt-1 text-[13px] text-inkmuted">
            {status === 'ready' ? `共 ${versions.length} 个发布版本` : '正在同步版本数据'}
          </p>
        </div>
        <button type="button" className={btnPrimary} onClick={() => setCreating(true)}>
          ＋ 新建版本
        </button>
      </div>

      {status === 'loading' && <LoadingBlock text="加载版本列表…" />}
      {status === 'error' && <ErrorBlock message={loadError} onRetry={() => void load()} />}
      {status === 'ready' &&
        (versions.length === 0 ? (
          <EmptyBlock
            title="还没有发布版本"
            hint="点击「新建版本」发布第一个 App 版本"
            action={
              <button type="button" className={btnPrimary} onClick={() => setCreating(true)}>
                ＋ 新建版本
              </button>
            }
          />
        ) : (
          <section className="rounded-card border border-track bg-card shadow-sm">
            <div className="overflow-x-auto">
              <table className="w-full min-w-[860px] text-left text-sm">
                <thead>
                  <tr className="border-b border-track text-xs text-inkmuted">
                    <th className="px-4 py-3 font-medium">版本号</th>
                    <th className="px-4 py-3 font-medium">versionCode</th>
                    <th className="px-4 py-3 font-medium">强制更新</th>
                    <th className="px-4 py-3 font-medium">状态</th>
                    <th className="px-4 py-3 font-medium">发布时间</th>
                    <th className="px-4 py-3 font-medium">APK 地址</th>
                    <th className="px-4 py-3 text-right font-medium">操作</th>
                  </tr>
                </thead>
                <tbody>
                  {versions.map((v) => (
                    <tr
                      key={v.id}
                      className="border-b border-track/60 align-middle transition last:border-0 hover:bg-paper/70"
                      title={`更新于 ${fmtTime(v.updatedAt)}`}
                    >
                      <td className="max-w-56 px-4 py-3">
                        <p className="font-mono font-semibold text-ink">{v.version}</p>
                        {v.notes && <p className="mt-0.5 line-clamp-1 text-xs text-inkmuted">{v.notes}</p>}
                      </td>
                      <td className="px-4 py-3 font-mono text-inkmuted">{v.versionCode}</td>
                      <td className="px-4 py-3">
                        <ForceBadge force={v.force} />
                      </td>
                      <td className="px-4 py-3">
                        <EnabledBadge enabled={v.enabled} />
                      </td>
                      <td className="whitespace-nowrap px-4 py-3 text-[13px] text-inkmuted">
                        {fmtTime(v.releasedAt)}
                      </td>
                      <td className="max-w-48 px-4 py-3">
                        {v.apkUrl ? (
                          <a
                            href={v.apkUrl}
                            target="_blank"
                            rel="noreferrer"
                            className="inline-block max-w-44 truncate font-mono text-xs text-accent hover:underline"
                            title={v.apkUrl}
                          >
                            {v.apkUrl}
                          </a>
                        ) : (
                          <span className="text-xs text-inkmuted">—</span>
                        )}
                      </td>
                      <td className="whitespace-nowrap px-4 py-3 text-right">
                        <div className="flex justify-end gap-2">
                          <button type="button" className={`${btnGhost} h-8`} onClick={() => setEditing(v)}>
                            编辑
                          </button>
                          <button
                            type="button"
                            className={`${btnDangerGhost} h-8`}
                            onClick={() => setPendingDelete(v)}
                          >
                            删除
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        ))}

      <Modal open={creating} title="新建版本" onClose={() => setCreating(false)}>
        <AppVersionForm
          submitting={submitting}
          submitLabel="创建版本"
          onSubmit={(input) => void handleCreate(input)}
          onCancel={() => setCreating(false)}
        />
      </Modal>

      <Modal
        open={editing !== null}
        title={editing ? `编辑版本 ${editing.version}` : '编辑版本'}
        onClose={() => setEditing(null)}
      >
        <AppVersionForm
          initial={editing}
          submitting={submitting}
          submitLabel="保存修改"
          onSubmit={(input, enabled) => void handleUpdate({ ...input, enabled })}
          onCancel={() => setEditing(null)}
        />
      </Modal>

      <ConfirmDialog
        open={pendingDelete !== null}
        title="删除版本"
        message={`确定删除版本「${pendingDelete?.version ?? ''}」（versionCode ${pendingDelete?.versionCode ?? ''}）吗？此操作不可恢复。`}
        loading={deleting}
        onConfirm={() => void handleDelete()}
        onCancel={() => setPendingDelete(null)}
      />
    </div>
  )
}
