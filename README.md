# 码上读 code-tutorials

开源中文编程教程 App：Flutter Android 客户端 + Golang 内容 API。教程内容存后端数据库、在线更新，App 端缓存支持离线阅读，阅读进度存本机。

## 目录结构

```
backend/   Go + Gin + GORM + SQLite 内容 API（接口文档见 backend/API.md）
mobile/    Flutter Android 客户端
design.md  冻结的 UI 设计系统（颜色/字体/组件规范）
```

## 快速开始

### 1. 启动后端（默认 :8080）

```bash
cd backend
go run .
```

首次启动自动建库并写入 2 门示例课程（Go 入门 3 章、Python 基础 2 章）。数据库文件在 `backend/data/tutorials.db`。

环境变量：`PORT`（端口）、`TUTORIALS_DB`（SQLite 路径）。

### 2. 运行 App

```bash
cd mobile
flutter run            # 模拟器默认连 http://10.0.2.2:8080
```

或直接安装已构建的调试包：`mobile/build/app/outputs/flutter-apk/app-debug.apk`。

真机使用：安装后在"设置"页把服务器地址改成电脑的局域网 IP（如 `http://192.168.1.10:8080`），手机与电脑需同一网络。

## 功能

- 课程列表（筛选：全部 / 学习中 / 未开始）与继续阅读
- 章节在线阅读：Markdown + 代码块高亮容器 + 一键复制
- 阅读进度本机记录（已读章节、整体进度条）
- 内容缓存：断网自动读缓存，无缓存显示空态引导
- iOS 26 液态玻璃底部导航 + 手动同步按钮

## 技术栈

- 后端：Go 1.26 · Gin · GORM · glebarez/sqlite（纯 Go，无 CGO）
- 客户端：Flutter 3.47 · provider · flutter_markdown · shared_preferences · liquid_glass_widgets

## 文档

- API 契约与示例：[backend/API.md](backend/API.md)
- 设计系统：[design.md](design.md)

## License

[MIT](LICENSE)
