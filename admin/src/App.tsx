import { Outlet, RouterProvider, createHashRouter } from 'react-router-dom'
import { TopBar } from './components/TopBar'
import { ChapterEditPage } from './pages/ChapterEditPage'
import { CourseDetailPage } from './pages/CourseDetailPage'
import { CourseListPage } from './pages/CourseListPage'
import { SettingsProvider } from './SettingsContext'
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

const routes = [
  {
    element: <Layout />,
    children: [
      { path: '/', element: <CourseListPage /> },
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
