import { memo } from 'react'
import { Link } from 'react-router-dom'
import type { Course } from '../api/types'
import { fmtTime } from '../lib/format'
import { LanguageTag } from './LanguageTag'

export const CourseCard = memo(function CourseCard({ course }: { course: Course }) {
  return (
    <Link
      to={`/courses/${encodeURIComponent(course.slug)}`}
      className="group flex min-h-44 flex-col rounded-card border border-track bg-card p-[18px] pb-4 shadow-sm transition hover:border-accent/50 hover:shadow-md"
    >
      <div className="flex items-center justify-between gap-2">
        <LanguageTag language={course.language} />
        <span className="text-xs text-inkmuted">{fmtTime(course.updated_at)}</span>
      </div>
      <h3 className="mt-3 text-xl font-bold leading-snug text-ink transition group-hover:text-accent">
        {course.title}
      </h3>
      <p className="mt-1.5 line-clamp-2 min-h-10 text-[13px] leading-relaxed text-inkmuted">
        {course.summary || '暂无简介'}
      </p>
      <div className="mt-auto flex items-center justify-between gap-2 pt-3">
        <span className="font-mono text-[13px] text-inkmuted">{course.chapter_count ?? 0} 章</span>
        <span className="flex min-w-0 items-center gap-1.5 font-mono text-xs text-inkmuted">
          <span
            className="inline-block h-3 w-3 shrink-0 rounded-full border border-track"
            style={{ backgroundColor: course.color || 'transparent' }}
            aria-hidden
          />
          <span className="truncate">{course.slug}</span>
        </span>
      </div>
    </Link>
  )
})
