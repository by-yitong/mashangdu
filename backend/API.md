# 码上读 后端 API 文档

教程内容 API。Golang + Gin + GORM + SQLite（驱动 `github.com/glebarez/sqlite`，纯 Go 无 CGO）。

- Base URL：`http://localhost:8080/api/v1`
- 方法：内容接口（1～4）为只读 `GET`；管理端接口（5～10，`/api/v1/admin` 前缀）提供写操作
- 认证：内容接口无认证；管理端接口需要请求头 `X-Admin-Token`（见下文"管理端鉴权"）
- CORS：允许所有来源（开发期），预检 `OPTIONS` 返回 204；允许方法 `GET, POST, PUT, DELETE, OPTIONS`，允许头含 `X-Admin-Token`

## 启动

```bash
cd backend
go run .
```

| 环境变量 | 默认值 | 说明 |
| --- | --- | --- |
| `PORT` | `8080` | 监听端口 |
| `TUTORIALS_DB` | `data/tutorials.db` | SQLite 数据库文件路径（相对 backend/ 启动目录） |
| `ADMIN_TOKEN` | （空） | 管理端鉴权 token；未设置或为空时管理端整体禁用（一律 403） |

## 数据播种（seed）

- 若 `internal/store/seeddata/courses.json` 存在，服务启动时按其 **upsert**：课程按 `slug`、章节按 `(course_id, slug)` 存在则更新、不存在则创建，**永不删除**。章节的 `file` 字段为相对 seeddata 目录的 markdown 文件名，读取其全文作为 `content_md`；仅在内容真正变化时才写库（避免无谓抬高 `content_version`）。schema 参考 `internal/store/seeddata/courses.example.json`（示例文件，引用内置 5 章，供测试使用）。
- `courses.json` 不存在时保持原行为：`courses` 表为空则播种内置示例数据（go-basics 3 章、python-basics 2 章）。
- `courses.json` 格式错误或引用的 md 文件缺失时，服务启动失败（fail fast）。

## 后台静态托管（生产部署）

若目录 `backend/admin/dist` 存在（React 后台构建产物），服务自动将其挂载到 `/admin`，且 `/admin/` 前缀的未知路径回退到 `dist/index.html`（SPA history 路由）；目录不存在时该行为完全不存在。`admin/dist/` 已加入 `backend/.gitignore`。

## 响应信封

所有响应均为统一信封：

```json
{"code": "<字符串>", "message": "<字符串>", "data": <object|null>}
```

| code | HTTP | data |
| --- | --- | --- |
| `OK` | 200 | 具体数据，`message` 固定为 `"ok"` |
| `FORBIDDEN` | 403 | `null`（仅管理端） |
| `BAD_REQUEST` | 400 | `null`（仅管理端） |
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

> 版本号语义：`content_version` 取存活行的最大 `updated_at`，**删除不会降低版本号**（剩余行的 `updated_at` 不变，版本号保持，直到下一次创建/修改）。

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
    "order": 1,
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

## 管理端接口（5～10）

供 React 后台（`/admin`）调用的内容管理接口。除下方差异外，信封、时间格式与内容接口一致。

### 管理端鉴权

- 所有管理端请求必须带请求头 `X-Admin-Token`，其值等于环境变量 `ADMIN_TOKEN`。
- `ADMIN_TOKEN` 未设置或为空：管理端整体禁用，任何管理端请求一律返回 403：

```json
{"code": "FORBIDDEN", "message": "admin disabled: ADMIN_TOKEN not set", "data": null}
```

- 请求头缺失或不匹配：返回 403：

```json
{"code": "FORBIDDEN", "message": "invalid admin token", "data": null}
```

### 字段约定

- `color`：格式 `#RRGGBB`（如 `#14B8A6`）；可空，缺省默认 `#14B8A6`；非法格式返回 400。
- `sort_order`：整数；创建时缺省排最后（同表最大值 + 1）；更新时缺省表示保持原值。
- `slug` 创建后不可改：更新接口以 path 中的 slug 定位资源，body 中的 `slug` 字段被忽略。
- 更新接口为按字段覆盖：`title` 必填；课程 `summary`/`language`/`color` 缺省时按默认值覆盖；章节 `content_md` 缺省时保持原值。

---

## 5. POST /api/v1/admin/courses

创建课程。

### 请求头

| 头 | 说明 |
| --- | --- |
| `X-Admin-Token` | 管理端 token，见"管理端鉴权" |

### 请求体

```json
{
  "slug": "rust-basics",
  "title": "Rust 入门",
  "summary": "从所有权到并发，跑通 Rust 学习第一段路。",
  "language": "Rust",
  "color": "#F97316",
  "sort_order": 3
}
```

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `slug` | string | 是 | 全局唯一，重复返回 400 |
| `title` | string | 是 | |
| `summary` | string | 否 | |
| `language` | string | 否 | |
| `color` | string | 否 | `#RRGGBB`，缺省 `#14B8A6` |
| `sort_order` | int | 否 | 缺省排最后（最大值 + 1） |

### 成功响应 200（data 为课程对象，同 GET /courses/{slug} 结构，chapters 为 []）

```json
{
  "code": "OK",
  "message": "ok",
  "data": {
    "slug": "rust-basics",
    "title": "Rust 入门",
    "summary": "从所有权到并发，跑通 Rust 学习第一段路。",
    "language": "Rust",
    "color": "#F97316",
    "updated_at": "2026-10-15T11:30:58Z",
    "chapters": []
  }
}
```

### 失败响应

400（缺 slug/缺 title/color 非法）：

```json
{"code": "BAD_REQUEST", "message": "slug is required", "data": null}
```

```json
{"code": "BAD_REQUEST", "message": "title is required", "data": null}
```

```json
{"code": "BAD_REQUEST", "message": "invalid color: want #RRGGBB", "data": null}
```

400（slug 已存在）：

```json
{"code": "BAD_REQUEST", "message": "course slug already exists", "data": null}
```

403：见"管理端鉴权"。请求体非法 JSON 亦返回 400 `{"code":"BAD_REQUEST","message":"invalid request body","data":null}`（下同，各接口不再重复列出）。

---

## 6. PUT /api/v1/admin/courses/{slug}

更新课程（slug 不可改，以 path 为准）。

### 参数

| 参数 | 位置 | 说明 |
| --- | --- | --- |
| `slug` | path | 课程标识 |

### 请求体

与创建相同（`slug` 字段被忽略）；`sort_order` 缺省保持原值。

```json
{
  "title": "Rust 进阶",
  "summary": "新摘要",
  "language": "Rust",
  "color": "#3B82F6",
  "sort_order": 0
}
```

### 成功响应 200（data 为更新后的课程对象，chapters 为当前章节目录）

```json
{
  "code": "OK",
  "message": "ok",
  "data": {
    "slug": "rust-basics",
    "title": "Rust 进阶",
    "summary": "新摘要",
    "language": "Rust",
    "color": "#3B82F6",
    "updated_at": "2026-10-15T11:31:58Z",
    "chapters": []
  }
}
```

### 失败响应 404（课程不存在）

```json
{"code": "NOT_FOUND", "message": "course not found", "data": null}
```

---

## 7. DELETE /api/v1/admin/courses/{slug}

删除课程，连同其全部章节。

### 参数

| 参数 | 位置 | 说明 |
| --- | --- | --- |
| `slug` | path | 课程标识 |

### 成功响应 200

```json
{"code": "OK", "message": "ok", "data": {"deleted": true}}
```

### 失败响应 404（课程不存在）

```json
{"code": "NOT_FOUND", "message": "course not found", "data": null}
```

---

## 8. POST /api/v1/admin/courses/{slug}/chapters

在课程下创建章节。

### 参数

| 参数 | 位置 | 说明 |
| --- | --- | --- |
| `slug` | path | 课程标识，课程不存在返回 404 |

### 请求体

```json
{
  "slug": "ownership",
  "title": "所有权入门",
  "content_md": "## 所有权\n\nRust 的核心概念……",
  "sort_order": 1
}
```

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `slug` | string | 是 | 同课程内唯一，重复返回 400 |
| `title` | string | 是 | |
| `content_md` | string | 否 | markdown 正文，缺省为空串 |
| `sort_order` | int | 否 | 缺省排最后（该课程内最大值 + 1） |

### 成功响应 200（data 为章节对象）

```json
{
  "code": "OK",
  "message": "ok",
  "data": {
    "slug": "ownership",
    "course_slug": "rust-basics",
    "title": "所有权入门",
    "order": 1,
    "updated_at": "2026-10-15T11:32:58Z"
  }
}
```

### 失败响应

404（课程不存在）：

```json
{"code": "NOT_FOUND", "message": "course not found", "data": null}
```

400（chapter slug 与该课程下已有章节重复）：

```json
{"code": "BAD_REQUEST", "message": "chapter slug already exists", "data": null}
```

---

## 9. PUT /api/v1/admin/courses/{slug}/chapters/{chapterSlug}

更新章节（slug 不可改，以 path 为准）。

### 参数

| 参数 | 位置 | 说明 |
| --- | --- | --- |
| `slug` | path | 课程标识，不存在返回 404 |
| `chapterSlug` | path | 章节标识，不存在返回 404 |

### 请求体

与创建相同（`slug` 字段被忽略）；`content_md`、`sort_order` 缺省时保持原值，`title` 必填。

```json
{
  "title": "所有权（修订）",
  "content_md": "## 所有权 v2\n\n更新后的正文……"
}
```

### 成功响应 200（data 为更新后的章节对象，结构同创建）

```json
{
  "code": "OK",
  "message": "ok",
  "data": {
    "slug": "ownership",
    "course_slug": "rust-basics",
    "title": "所有权（修订）",
    "order": 1,
    "updated_at": "2026-10-15T11:33:58Z"
  }
}
```

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

## 10. DELETE /api/v1/admin/courses/{slug}/chapters/{chapterSlug}

删除章节。

### 参数

| 参数 | 位置 | 说明 |
| --- | --- | --- |
| `slug` | path | 课程标识，不存在返回 404 |
| `chapterSlug` | path | 章节标识，不存在返回 404 |

### 成功响应 200

```json
{"code": "OK", "message": "ok", "data": {"deleted": true}}
```

### 失败响应 404

```json
{"code": "NOT_FOUND", "message": "chapter not found", "data": null}
```

> 删除（课程或章节）不会降低 GET /meta 的 `content_version`（见接口 1 的版本号语义）。

---

## 错误码汇总

| HTTP | code | 场景 |
| --- | --- | --- |
| 200 | `OK` | 成功 |
| 400 | `BAD_REQUEST` | 管理端：请求体非法 JSON（`invalid request body`）、缺 slug/`slug is required`、缺 title/`title is required`、color 非法（`invalid color: want #RRGGBB`）、课程 slug 重复（`course slug already exists`）、章节 slug 重复（`chapter slug already exists`） |
| 403 | `FORBIDDEN` | 管理端：`ADMIN_TOKEN` 未设置（`admin disabled: ADMIN_TOKEN not set`）或 token 不匹配（`invalid admin token`） |
| 404 | `NOT_FOUND` | 路径不存在、课程不存在（`course not found`）、章节不存在（`chapter not found`） |
| 500 | `INTERNAL` | 服务器内部错误（`internal error`） |

## 数据模型

- **courses**：`ID`、`Slug`（唯一）、`Title`、`Summary`、`Language`、`Color`、`SortOrder`、`CreatedAt`、`UpdatedAt`
- **chapters**：`ID`、`CourseID`（外键，联合唯一首列 + 可作单列索引前缀）、`Slug`（联合唯一 `idx_chapters_course_slug(CourseID, Slug)`）、`Title`、`ContentMD`（markdown 正文）、`SortOrder`、`CreatedAt`、`UpdatedAt`

表结构由 GORM AutoMigrate 自动创建。
