import { memo } from 'react'

/** 语言标签块配色：低饱和浅底 + 深字（design.md 浅色版规则） */
const LANG_STYLES: Record<string, { bg: string; fg: string }> = {
  go: { bg: '#E6F5F3', fg: '#0F766E' },
  python: { bg: '#EDF1FA', fg: '#4C6BB0' },
  rust: { bg: '#F3E9E4', fg: '#99482F' },
  javascript: { bg: '#F6F1DC', fg: '#7A6C1F' },
  typescript: { bg: '#EAF0F9', fg: '#3B5FA8' },
  java: { bg: '#FAECE7', fg: '#B0532F' },
  'c++': { bg: '#EEF0F6', fg: '#5A6390' },
  c: { bg: '#EEF0F6', fg: '#5A6390' },
}

const FALLBACK_STYLE = { bg: '#E6F1EF', fg: '#3F7268' }

function lookup(language: string): { bg: string; fg: string } {
  return LANG_STYLES[language.trim().toLowerCase()] ?? FALLBACK_STYLE
}

export const LanguageTag = memo(function LanguageTag({ language }: { language: string }) {
  const style = lookup(language)
  return (
    <span
      className="inline-block rounded-md px-2 py-0.5 text-xs font-semibold"
      style={{ backgroundColor: style.bg, color: style.fg }}
    >
      {language || '未设置语言'}
    </span>
  )
})
