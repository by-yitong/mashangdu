# 码上读 code-tutorials

开源中文编程教程 App：Flutter Android 客户端 + Golang 内容 API + React 管理后台。教程内容存后端数据库、在线更新，App 端缓存支持离线阅读，阅读进度存本机。

## 目录结构

```
backend/   Go + Gin + GORM + SQLite 内容 API 与管理 API（接口文档见 backend/API.md）
backend/admin/dist/   React 管理后台构建产物（后端托管在 /admin）
admin/     React 管理后台源码（Vite + React + TS + Tailwind，Markdown 编辑器）
mobile/    Flutter Android 客户端
content:   教程内容在 backend/internal/store/seeddata/（courses.json + 148 章 Markdown）
tools/     教程爬取入库脚本（mkdocs 文档站 → seed 格式，详见 skills/crawl-tutorials）
design.md  冻结的 UI 设计系统（颜色/字体/组件规范）
```

## 快速开始

### 1. 启动后端（默认 :8080）

```bash
cd backend
ADMIN_TOKEN=your-token go run .   # 设置管理令牌，后台写接口需要
```

首次启动自动建库并按 `seeddata/courses.json` 写入 5 门课程（Go 10 章、Python 10 章、JavaScript 6 章、SQL 5 章、Hello 算法 117 章）。其中《Hello 算法》来自开源书 [hello-algo.com](https://www.hello-algo.com/)（krahets 著），按 CC BY-NC-SA 4.0 授权转载，仅限非商业用途。内容文件改动后重启即 upsert（按 slug 更新，永不删除）。数据库文件在 `backend/data/tutorials.db`。

环境变量：`PORT`（端口）、`TUTORIALS_DB`（SQLite 路径）、`ADMIN_TOKEN`（管理令牌，不设则管理 API 全部 403）。

### 2. 运行 App

```bash
cd mobile
flutter run            # debug 构建默认连 http://192.168.31.15:8080
```

或直接安装已构建的调试包：`mobile/build/app/outputs/flutter-apk/app-debug.apk`。

- release 构建默认连 `https://study.phpcurl.cn`：`flutter build apk --release`
- 服务器地址随时可在 App"设置"页修改（当前值优先于默认值）

### 3. 管理后台（写教程）

```bash
cd admin
npm i
npm run dev            # http://localhost:5173/admin/，/api 代理到 localhost:8080
```

右上角设置里填 Admin Token（与后端 `ADMIN_TOKEN` 一致）即可新建/编辑课程与章节，章节编辑器为左右分栏 Markdown（实时预览 + 工具栏）。生产部署：`npm run build` 后把 `admin/dist` 复制到 `backend/admin/dist`，后端自动托管在 `http://<host>:8080/admin/`。

## 功能

- 课程列表（筛选：全部 / 学习中 / 未开始）与继续阅读
- 章节在线阅读：Markdown + 代码语法高亮（Go/Python/JS/SQL/Rust/Java 等）+ 一键复制 + 三档字号调节
- 阅读沉浸：下滑隐藏标题栏、上滑浮回；底部章节进度条与上一章/下一章
- 浅色 / 深色 / 跟随系统三种外观，设置页切换
- 阅读进度本机记录（已读章节、整体进度条），课程页章节搜索 + 下拉刷新
- 内容缓存：断网自动读缓存，无缓存显示空态引导
- iOS 26 液态玻璃底部导航；首页下拉刷新同步

## 技术栈

- 后端：Go 1.26 · Gin · GORM · glebarez/sqlite（纯 Go，无 CGO）
- 客户端：Flutter 3.47 · provider · flutter_markdown · highlight · shared_preferences · liquid_glass_widgets
- 管理后台：React 18 · Vite · TypeScript · Tailwind · react-markdown

## 文档

- API 契约与示例（含管理 API）：[backend/API.md](backend/API.md)
- 设计系统：[design.md](design.md)

## License

[MIT](LICENSE)

