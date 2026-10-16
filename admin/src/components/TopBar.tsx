import { Link, NavLink, useNavigate } from 'react-router-dom'
import { useSettings } from '../SettingsContext'
import { btnGhost } from './ui'

const NAV_LINKS = [
  { to: '/', label: '课程', end: true },
  { to: '/app-versions', label: '版本管理' },
]

function navLinkCls({ isActive }: { isActive: boolean }) {
  return `inline-flex h-8 items-center rounded-full px-3 text-[13px] font-medium transition ${
    isActive ? 'bg-accent/10 text-accent' : 'text-inkmuted hover:bg-track/60 hover:text-ink'
  }`
}

export function TopBar() {
  const { update } = useSettings()
  const navigate = useNavigate()

  // 退出登录：清空 token，回登录页重新验证
  const handleLogout = () => {
    update({ token: '' })
    navigate('/login', { replace: true })
  }

  return (
    <header className="sticky top-0 z-40 border-b border-track bg-card/90 backdrop-blur">
      <div className="mx-auto flex h-14 w-full max-w-6xl items-center justify-between px-4">
        <div className="flex items-center gap-5">
          <Link to="/" className="flex items-center gap-2">
            <span className="flex h-7 w-7 items-center justify-center rounded-lg bg-accent text-sm font-bold text-white">
              码
            </span>
            <span className="text-[15px] font-bold text-ink">码上读后台</span>
          </Link>
          <nav className="flex items-center gap-1" aria-label="主导航">
            {NAV_LINKS.map((item) => (
              <NavLink key={item.to} to={item.to} end={item.end} className={navLinkCls}>
                {item.label}
              </NavLink>
            ))}
          </nav>
        </div>

        <div className="flex items-center gap-3">
          <button
            type="button"
            className={`${btnGhost} h-8 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/40`}
            onClick={handleLogout}
          >
            退出登录
          </button>
        </div>
      </div>
    </header>
  )
}
