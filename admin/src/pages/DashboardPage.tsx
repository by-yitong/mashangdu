import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { errMsg, getStats } from '../api/client'
import type { AdminStats } from '../api/types'
import { Avatar } from '../components/Avatar'
import { ErrorBlock, LoadingBlock } from '../components/States'
import { fmtTime, formatInt } from '../lib/format'

type Status = 'loading' | 'ready' | 'error'

/** 卡片小标题右侧的「查看全部」入口 */
function CardMoreLink({ to }: { to: string }) {
  return (
    <Link to={to} className="text-xs font-medium text-accent hover:underline">
      查看全部
    </Link>
  )
}

/** 内容卡通用外壳：标题 + 右侧入口 + 列表/空态 */
function ContentCard({ title, moreTo, children }: { title: string; moreTo: string; children: ReactNode }) {
  return (
    <section className="flex flex-col rounded-card border border-track bg-card p-5 shadow-sm">
      <div className="flex items-center justify-between gap-3">
        <h2 className="text-base font-bold text-ink">{title}</h2>
        <CardMoreLink to={moreTo} />
      </div>
      {children}
    </section>
  )
}

/** 内容卡空态：简洁占位文案 */
function CardEmpty({ text }: { text: string }) {
  return <p className="mt-4 flex-1 rounded-2xl border border-dashed border-track bg-paper px-4 py-8 text-center text-[13px] text-inkmuted">{text}</p>
}

export function DashboardPage() {
  const [status, setStatus] = useState<Status>('loading')
  const [stats, setStats] = useState<AdminStats | null>(null)
  const [loadError, setLoadError] = useState('')

  const load = useCallback(async () => {
    setStatus('loading')
    setLoadError('')
    try {
      const data = await getStats()
      setStats(data)
      setStatus('ready')
    } catch (e) {
      setLoadError(errMsg(e))
      setStatus('error')
    }
  }, [])

  useEffect(() => {
    void load()
  }, [load])

  // 指标卡数据：由 stats 派生，避免渲染期重复取值
  const metricCards = useMemo(() => {
    if (!stats) return []
    return [
      { label: '课程数', value: stats.courseCount },
      { label: '章节数', value: stats.chapterCount },
      { label: '总阅读量', value: stats.totalViews },
      { label: '用户数', value: stats.userCount },
      { label: '评论数', value: stats.commentCount },
      { label: '点赞数', value: stats.likeCount },
    ]
  }, [stats])

  return (
    <div className="flex flex-col gap-5">
      <div>
        <h1 className="text-[32px] font-bold leading-tight text-ink">概况</h1>
        <p className="mt-1 text-[13px] text-inkmuted">
          {status === 'ready' && stats
            ? stats.contentVersion
              ? `内容版本 ${stats.contentVersion}`
              : '暂无内容'
            : '正在同步全站数据'}
        </p>
      </div>

      {status === 'loading' && <LoadingBlock text="加载概况数据…" />}
      {status === 'error' && <ErrorBlock message={loadError} onRetry={() => void load()} />}
      {status === 'ready' && stats && (
        <>
          {/* 指标卡区：6 张统计卡 */}
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {metricCards.map((card) => (
              <div key={card.label} className="rounded-card border border-track bg-card p-5 shadow-sm">
                <p className="text-[13px] text-inkmuted">{card.label}</p>
                <p className="mt-1.5 text-3xl font-bold leading-none text-ink">{formatInt(card.value)}</p>
              </div>
            ))}
          </div>

          {/* 内容卡区：热门章节 / 最新用户 / 最新评论 */}
          <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
            <ContentCard title="热门章节 Top5" moreTo="/courses">
              {stats.topChapters.length === 0 ? (
                <CardEmpty text="还没有章节阅读数据" />
              ) : (
                <ol className="mt-2">
                  {stats.topChapters.slice(0, 5).map((item) => (
                    <li
                      key={`${item.courseSlug}/${item.chapterSlug}`}
                      className="flex items-center justify-between gap-3 border-b border-track/60 py-2.5 last:border-0"
                    >
                      <div className="min-w-0">
                        <p className="truncate text-sm font-medium text-ink" title={item.chapterTitle}>
                          {item.chapterTitle}
                        </p>
                        <p className="truncate text-xs text-inkmuted" title={item.courseTitle}>
                          {item.courseTitle}
                        </p>
                      </div>
                      <span className="shrink-0 text-xs font-medium text-inkmuted">
                        {formatInt(item.viewCount)} 次阅读
                      </span>
                    </li>
                  ))}
                </ol>
              )}
            </ContentCard>

            <ContentCard title="最新注册用户" moreTo="/users">
              {stats.recentUsers.length === 0 ? (
                <CardEmpty text="还没有用户注册" />
              ) : (
                <ul className="mt-2">
                  {stats.recentUsers.map((user) => (
                    <li
                      key={user.id}
                      className="flex items-center gap-3 border-b border-track/60 py-2.5 last:border-0"
                    >
                      <Avatar username={user.username} avatar={user.avatar} />
                      <div className="min-w-0">
                        <p className="truncate text-sm font-medium text-ink">{user.username}</p>
                        <p className="text-xs text-inkmuted">{fmtTime(user.createdAt)} 注册</p>
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </ContentCard>

            <ContentCard title="最新评论" moreTo="/comments">
              {stats.recentComments.length === 0 ? (
                <CardEmpty text="还没有评论" />
              ) : (
                <ul className="mt-2">
                  {stats.recentComments.map((comment) => (
                    <li
                      key={comment.id}
                      className="border-b border-track/60 py-2.5 last:border-0"
                    >
                      <div className="flex items-baseline justify-between gap-3">
                        <p className="truncate text-sm font-medium text-ink">
                          {comment.username}
                          <span className="ml-1.5 font-normal text-xs text-inkmuted">
                            评论了「{comment.chapterTitle}」
                          </span>
                        </p>
                        <span className="shrink-0 text-xs text-inkmuted">{fmtTime(comment.createdAt)}</span>
                      </div>
                      <p className="mt-0.5 truncate text-[13px] text-inkmuted" title={comment.content}>
                        {comment.content}
                      </p>
                    </li>
                  ))}
                </ul>
              )}
            </ContentCard>
          </div>
        </>
      )}
    </div>
  )
}
