/** 把 ISO 时间格式化为 YYYY-MM-DD HH:mm；空值/非法值回退显示 */
export function fmtTime(iso: string | undefined): string {
  if (!iso) return '—'
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return iso
  const p = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`
}

/** 整数千分位格式化（用于概况页指标等大数展示） */
export function formatInt(value: number): string {
  return value.toLocaleString('en-US')
}
