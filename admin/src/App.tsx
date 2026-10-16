import { Navigate, Outlet, RouterProvider, createHashRouter, useLocation } from 'react-router-dom'
import { TopBar } from './components/TopBar'
import { AppVersionListPage } from './pages/AppVersionListPage'
import { ChapterEditPage } from './pages/ChapterEditPage'
import { CommentListPage } from './pages/CommentListPage'
import { CourseDetailPage } from './pages/CourseDetailPage'
import { CourseImportPage } from './pages/CourseImportPage'
import { CourseListPage } from './pages/CourseListPage'
import { LoginPage } from './pages/LoginPage'
import { SettingsProvider, useSettings } from './SettingsContext'
import { ToastProvider } from './ToastProvider'

function Layout() {
  return (
    <div className="min-h-screen bg-paper text-ink">
      <TopBar />
      <main className="mx-auto w-full max-w-6xl px-4 py-6">
        <Outlet />
      </main>
    </div>
  )
}

/** 路由守卫：未保存管理令牌时跳登录页，并记录来路供登录成功后回跳 */
function RequireToken() {
  const { settings } = useSettings()
  const location = useLocation()
  if (!settings.token) {
    return <Navigate to="/login" replace state={{ from: location }} />
  }
  return <Layout />
}

const routes = [
  // 登录页独立于 Layout（无 TopBar），不受守卫保护
  { path: '/login', element: <LoginPage /> },
  {
    element: <RequireToken />,
    children: [
      { path: '/', element: <CourseListPage /> },
      { path: '/course-import', element: <CourseImportPage /> },
      { path: '/app-versions', element: <AppVersionListPage /> },
      { path: '/comments', element: <CommentListPage /> },
      { path: '/courses/:slug', element: <CourseDetailPage /> },
      { path: '/courses/:slug/chapters/new', element: <ChapterEditPage /> },
      { path: '/courses/:slug/chapters/:chapterSlug', element: <ChapterEditPage /> },
    ],
  },
]

// Hash 路由：构建产物由后端托管在 /admin 下，无需 SPA fallback 配置
const router = createHashRouter(routes)

export default function App() {
  return (
    <SettingsProvider>
      <ToastProvider>
        <RouterProvider router={router} />
      </ToastProvider>
    </SettingsProvider>
  )
}
