import { useEffect, useState } from 'react'

export type SnippetKind = 'heading' | 'bold' | 'inlineCode' | 'codeBlock' | 'list' | 'orderedList' | 'link'

export interface InsertResult {
  text: string
  selectionStart: number
  selectionEnd: number
}

/**
 * 在 Markdown 源文本的选区位置插入模板。
 * heading/list/orderedList 插在光标所在行首；其余包裹选区（或占位文本）。
 */
export function insertSnippet(source: string, start: number, end: number, kind: SnippetKind): InsertResult {
  switch (kind) {
    case 'heading':
    case 'list':
    case 'orderedList': {
      const prefix = kind === 'heading' ? '## ' : kind === 'list' ? '- ' : '1. '
      const lineStart = source.lastIndexOf('\n', Math.max(0, start - 1)) + 1
      const text = source.slice(0, lineStart) + prefix + source.slice(lineStart)
      return { text, selectionStart: start + prefix.length, selectionEnd: end + prefix.length }
    }
    case 'bold':
      return wrap(source, start, end, '**', '**', '加粗文本')
    case 'inlineCode':
      return wrap(source, start, end, '`', '`', 'code')
    case 'codeBlock':
      return wrap(source, start, end, '\n```\n', '\n```\n', '// 代码')
    case 'link': {
      const label = source.slice(start, end) || '链接文字'
      const text = `${source.slice(0, start)}[${label}](https://)${source.slice(end)}`
      const s = start + 1
      return { text, selectionStart: s, selectionEnd: s + label.length }
    }
  }
}

function wrap(source: string, start: number, end: number, before: string, after: string, placeholder: string): InsertResult {
  const inner = source.slice(start, end) || placeholder
  const text = source.slice(0, start) + before + inner + after + source.slice(end)
  const s = start + before.length
  return { text, selectionStart: s, selectionEnd: s + inner.length }
}

/** 防抖值 hook：预览等重计算场景延迟同步 */
export function useDebouncedValue<T>(value: T, delay = 300): T {
  const [debounced, setDebounced] = useState(value)
  useEffect(() => {
    const timer = window.setTimeout(() => setDebounced(value), delay)
    return () => window.clearTimeout(timer)
  }, [value, delay])
  return debounced
}
