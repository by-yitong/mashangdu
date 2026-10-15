# 码上读 后端 API 文档

教程内容 API。Golang + Gin + GORM + SQLite（驱动 `github.com/glebarez/sqlite`，纯 Go 无 CGO）。

- Base URL：`http://localhost:8080/api/v1`
- 方法：全部为 `GET`（当前无写接口）
- 认证：无
- CORS：允许所有来源（开发期），预检 `OPTIONS` 返回 204

## 启动

```bash
cd backend
go run .
```

| 环境变量 | 默认值 | 说明 |
| --- | --- | --- |
| `PORT` | `8080` | 监听端口 |
| `TUTORIALS_DB` | `data/tutorials.db` | SQLite 数据库文件路径（相对 backend/ 启动目录） |

首次启动时若 `courses` 表为空，自动播种 2 门示例课程（go-basics 3 章、python-basics 2 章），章正文为示例内容。

## 响应信封

所有响应均为统一信封：

```json
{"code": "<字符串>", "message": "<字符串>", "data": <object|null>}
```

| code | HTTP | data |
| --- | --- | --- |
| `OK` | 200 | 具体数据，`message` 固定为 `"ok"` |
| `NOT_FOUND` | 404 | `null` |
| `INTERNAL` | 500 | `null` |

所有时间字段均为 RFC3339 UTC 格式（如 `2026-10-15T10:30:58Z`）。

---

## 1. GET /api/v1/meta

内容元信息，客户端用于判断是否需要更新本地缓存。

### 参数

无。

### 成功响应 200

```json
{
  "code": "OK",
  "message": "ok",
  "data": {
    "content_version": "2026-10-15T10:30:58Z",
    "course_count": 2
  }
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `content_version` | string | 内容版本号 = courses + chapters 两表最大 `updated_at`（RFC3339 UTC） |
| `course_count` | int | 课程总数 |

---

## 2. GET /api/v1/courses

课程列表，按 `sort_order` 升序。

### 参数

无。

### 成功响应 200

```json
{
  "code": "OK",
  "message": "ok",
  "data": [
    {
      "slug": "go-basics",
      "title": "Go 语言入门",
      "summary": "从零开始学 Go：写出第一个程序、认识变量与类型，再到 goroutine 并发入门，跑通 Go 学习的第一段路。",
      "language": "Go",
      "color": "#14B8A6",
      "chapter_count": 3,
      "updated_at": "2026-10-15T10:30:58Z"
    },
    {
      "slug": "python-basics",
      "title": "Python 基础",
      "summary": "面向零基础读者的 Python 入门：装好环境、玩转 REPL，掌握变量与控制流，迈出编程第一步。",
      "language": "Python",
      "color": "#4C6BB0",
      "chapter_count": 2,
      "updated_at": "2026-10-15T10:30:58Z"
    }
  ]
}
```

---

## 3. GET /api/v1/courses/{slug}

单门课程详情，含章节目录（按 `order` 升序，不含正文）。

### 参数

| 参数 | 位置 | 说明 |
| --- | --- | --- |
| `slug` | path | 课程标识，如 `go-basics` |

### 成功响应 200

```json
{
  "code": "OK",
  "message": "ok",
  "data": {
    "slug": "go-basics",
    "title": "Go 语言入门",
    "summary": "从零开始学 Go：写出第一个程序、认识变量与类型，再到 goroutine 并发入门，跑通 Go 学习的第一段路。",
    "language": "Go",
    "color": "#14B8A6",
    "updated_at": "2026-10-15T10:30:58Z",
    "chapters": [
      {"slug": "hello-world", "title": "Hello World", "order": 1},
      {"slug": "variables", "title": "变量与基本类型", "order": 2},
      {"slug": "goroutine", "title": "goroutine 并发入门", "order": 3}
    ]
  }
}
```

### 失败响应 404（课程不存在）

```json
{"code": "NOT_FOUND", "message": "course not found", "data": null}
```

---

## 4. GET /api/v1/courses/{slug}/chapters/{chapterSlug}

章节正文（markdown 源文本）。

### 参数

| 参数 | 位置 | 说明 |
| --- | --- | --- |
| `slug` | path | 课程标识，如 `go-basics` |
| `chapterSlug` | path | 章节标识，如 `hello-world` |

### 成功响应 200

```json
{
  "code": "OK",
  "message": "ok",
  "data": {
    "slug": "hello-world",
    "course_slug": "go-basics",
    "title": "Hello World",
    "content_md": "## 从 Hello World 开始\n\n每一门编程语言的第一课几乎都是 Hello World，Go 也不例外。……\n\n```go\npackage main\n\nimport \"fmt\"\n\nfunc main() {\n\tfmt.Println(\"Hello, World!\")\n}\n```\n\n……",
    "updated_at": "2026-10-15T10:30:58Z"
  }
}
```

> `content_md` 为完整 markdown 正文，此处为节省篇幅截断展示；实际响应包含全文。

### 失败响应 404

课程不存在：

```json
{"code": "NOT_FOUND", "message": "course not found", "data": null}
```

课程存在但章节不存在：

```json
{"code": "NOT_FOUND", "message": "chapter not found", "data": null}
```

---

## 错误码汇总

| HTTP | code | 场景 |
| --- | --- | --- |
| 200 | `OK` | 成功 |
| 404 | `NOT_FOUND` | 路径不存在、课程不存在（`course not found`）、章节不存在（`chapter not found`） |
| 500 | `INTERNAL` | 服务器内部错误（`internal error`） |

## 数据模型

- **courses**：`ID`、`Slug`（唯一）、`Title`、`Summary`、`Language`、`Color`、`SortOrder`、`CreatedAt`、`UpdatedAt`
- **chapters**：`ID`、`CourseID`（外键，联合唯一首列 + 可作单列索引前缀）、`Slug`（联合唯一 `idx_chapters_course_slug(CourseID, Slug)`）、`Title`、`ContentMD`（markdown 正文）、`SortOrder`、`CreatedAt`、`UpdatedAt`

表结构由 GORM AutoMigrate 自动创建。
