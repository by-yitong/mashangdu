# 码上读 后端 API 文档

教程内容 API。Golang + Gin + GORM + SQLite（驱动 `github.com/glebarez/sqlite`，纯 Go 无 CGO）。

- Base URL：`http://localhost:8080/api/v1`
- 方法：内容接口（1～4）为只读 `GET`；管理端接口（5～10、10b、13b、16～18，`/api/v1/admin` 前缀）提供写操作；用户认证（11）与观看记录（12）为 `POST/GET/PUT/DELETE`；用户头像（14）与章节互动（15）为 `POST/GET/DELETE`
- 认证：内容接口、`GET /app/latest`、阅读量/评论列表（15a/15b/15d）无认证；`stats` 支持可选 Bearer；用户认证、头像上传、观看记录、点赞与发评论接口需要请求头 `Authorization: Bearer <token>`（见下文"用户认证（Bearer）"）；管理端接口需要请求头 `X-Admin-Token`（见下文"管理端鉴权"）
- CORS：允许所有来源（开发期），预检 `OPTIONS` 返回 204；允许方法 `GET, POST, PUT, DELETE, OPTIONS`，允许头含 `X-Admin-Token`、`Authorization`

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
| `AUTH_SECRET` | `dev-auth-secret` | 用户认证 JWT（HS256）签名密钥；未设置时使用开发默认值并在启动日志提醒，生产环境必须设置 |

## 数据播种（seed）

课程内容是**运行时数据**，不随二进制发布（二进制不携带任何文章），只来自两个途径：

1. **磁盘 seeddata**：若 `internal/store/seeddata/courses.json` 存在（相对进程工作目录自动探测，候选：`internal/store/seeddata`、`seeddata`、`../store/seeddata`、`backend/internal/store/seeddata`），服务启动时按其 **upsert**：课程按 `slug`、章节按 `(course_id, slug)` 存在则更新、不存在则创建，**永不删除**。章节的 `file` 字段为相对 seeddata 目录的 markdown 文件名，读取其全文作为 `content_md`；仅在内容真正变化时才写库（避免无谓抬高 `content_version`）。schema 参考 `internal/store/seeddata/courses.example.json`（示例文件，引用内置 5 章，供测试使用）。
2. **管理端导入接口**（见 10b）：运行时上传课程包 zip，解压 md/图片落盘到同一 seeddata 目录与图片根目录、按 slug 合并 courses.json，随即 upsert 进数据库，**无需重启服务**。

- `courses.json` 不存在时**空库启动**，不播种任何内容（无内置兜底示例）。
- `courses.json` 格式错误或引用的 md 文件缺失时，服务启动失败（fail fast）。

## 后台静态托管（生产部署）

admin 前端在编译期通过 go:embed 嵌入二进制（`backend/web/dist`，构建时由 admin 构建产物覆盖：先在仓库根 `admin/` 执行 `npm run build`，产物拷贝到 `backend/web/dist/` 后再 `go build`），`/admin` 永远可用且与 API 同源；`/admin/` 前缀的未知路径回退到 `dist/index.html`（SPA）。本地开发用 Vite dev server（`/api` 代理到 `:8080`），无需重建二进制。`backend/web/dist/` 中除占位 `index.html` 外均已加入 `backend/.gitignore`。

## 响应信封

所有响应均为统一信封：

```json
{"code": "<字符串>", "message": "<字符串>", "data": <object|null>}
```

| code | HTTP | data |
| --- | --- | --- |
| `OK` | 200 | 具体数据，`message` 固定为 `"ok"` |
| `OK` | 201 | 同上（仅注册、发布评论、管理端创建 App 版本） |
| `FORBIDDEN` | 403 | `null`（仅管理端） |
| `BAD_REQUEST` | 400 | `null`（管理端与用户端均有使用，code 语义按接口区分） |
| `AUTH_INVALID_INPUT` | 400 | `null`（仅用户端接口） |
| `AUTH_UNAUTHORIZED` | 401 | `null`（仅用户端接口） |
| `AUTH_INVALID_CREDENTIALS` | 401 | `null`（仅登录） |
| `AUTH_USERNAME_TAKEN` | 409 | `null`（仅注册） |
| `VERSION_CONFLICT` | 409 | `null`（仅管理端 App 版本） |
| `IMPORT_BAD_ZIP` | 400 | `null`（仅管理端课程包导入） |
| `IMPORT_INVALID_PACKAGE` | 400 | `null`（仅管理端课程包导入） |
| `IMPORT_MISSING_FILES` | 400 | `null`（仅管理端课程包导入） |
| `AVATAR_INVALID` | 400 | `null`（仅头像上传） |
| `COMMENT_INVALID_INPUT` | 400 | `null`（仅发布评论） |
| `COMMENT_FORBIDDEN` | 403 | `null`（仅删除他人评论） |
| `COMMENT_TOO_FAST` | 429 | `null`（仅发布评论频控） |
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

## 管理端接口（5～10、10b、13b、16～18）

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

## 10b. POST /api/v1/admin/courses/import（课程包导入）

上传课程包 zip，运行时导入课程内容：章节 md 与 courses.json 落盘到 seeddata 目录、图片落盘到图片根目录（`backend/static/images/`），按 slug 合并 courses.json 并**立即 upsert 进数据库，无需重启服务**。课程内容因此不随二进制发布（见"数据播种（seed）"）。

### 请求头

| 头 | 说明 |
| --- | --- |
| `X-Admin-Token` | 管理端 token，见"管理端鉴权" |

### 请求体（multipart/form-data）

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `file` | file | 是 | 课程包 zip 文件；请求体上限 600MB（超出返回 400） |

### zip 布局（根目录）

```text
courses.json          # 必需：{"courses":[课程条目,...]}，条目字段与磁盘种子格式完全一致
                      #   （slug/title/summary/language/color/sort_order/chapters[]，
                      #    chapters 元素：slug/title/sort_order/file）
*.md                  # 必需覆盖全部章节：章节正文，文件名与 chapters[].file 一致，位于 zip 根
images/**             # 可选：图片（支持多级子目录），解压到图片根目录下
                      #   （zip 内 images/x/y.png → static/images/x/y.png，同名覆盖）
```

校验与限额（任一不满足返回 400，见下方错误码）：

- 仅接受常规文件条目（拒绝目录条目、符号链接等）；条目名分隔符归一为 `/` 后校验，拒绝绝对路径、含 `..`、含盘符的条目。
- 条目数 ≤ 5000；总解压大小 ≤ 1GB（按 entry 头声明的 UncompressedSize64 预检 + 解压时按实际字节数累计复检）；单文件解压大小 ≤ 200MB。
- 根目录只允许 `courses.json`、`*.md`（必须位于根，不接受嵌套目录下的 md）、`images/**`；出现其他条目（如 `extra.txt`）返回 400 并在 message 中报出条目名。
- `courses.json` 必须可解析且 `courses` 数组非空；每门课 `slug`/`title` 必填、`chapters` 非空；每章 `slug`/`title` 必填且 `sort_order ≥ 1`；每章 `file` 必须存在于 zip 根，缺失则 400 并列出缺失文件名（最多 10 个）。
- 课程 slug 与磁盘已有课程重复时按"**原位替换**"处理（更新该课程，不算错误）；包内重复 slug 同样后者覆盖前者。

### 成功响应 200

`state`：导入前 DB 中不存在该课程 slug → `created`，否则 `updated`；`images` 仅统计本次实际解压的图片。

```json
{
  "code": "OK",
  "message": "ok",
  "data": {
    "courses": [
      {"slug": "jetpack-compose", "title": "Jetpack Compose 入门", "chapters": 58, "state": "created"}
    ],
    "images": {"count": 221, "bytes": 87320273}
  }
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `courses[].slug` | string | 课程标识 |
| `courses[].title` | string | 课程标题 |
| `courses[].chapters` | int | 该课程本次导入的章节数 |
| `courses[].state` | string | `created`（DB 中原不存在）/ `updated`（原已存在，原位替换） |
| `images.count` | int | 本次实际解压的图片个数 |
| `images.bytes` | int | 本次实际解压的图片总字节数 |

### 失败响应

400（`IMPORT_BAD_ZIP`：非 zip/损坏/条目超限/路径不安全/意外条目/请求体超 600MB）：

```json
{"code": "IMPORT_BAD_ZIP", "message": "path traversal in zip is not allowed: ../evil.md", "data": null}
```

`message` 示例：`multipart field 'file' is required` / `request body exceeds 600MB limit` / `invalid or corrupted zip file` / `zip entry is not a regular file: images/` / `too many zip entries (more than 5000)` / `zip entry big.md exceeds 200MB uncompressed size limit` / `total uncompressed size exceeds 1GB limit` / `absolute path in zip is not allowed: /etc/passwd` / `path traversal in zip is not allowed: ../evil.md` / `unexpected zip entry (only courses.json, *.md at root and images/** are allowed): extra.txt`。

400（`IMPORT_INVALID_PACKAGE`：courses.json 缺失或非法）：

```json
{"code": "IMPORT_INVALID_PACKAGE", "message": "courses.json missing from package", "data": null}
```

`message` 示例：`courses.json missing from package` / `invalid courses.json: courses array is empty` / `invalid courses.json: courses[0] (rust-basics) has no chapters` / `invalid courses.json: courses[0].chapters[2] (ownership) sort_order must be >= 1, got 0`。

400（`IMPORT_MISSING_FILES`：章节 md 缺失，最多列 10 个文件名）：

```json
{"code": "IMPORT_MISSING_FILES", "message": "chapter md files missing from zip: ch-03.md, ch-17.md", "data": null}
```

403：见"管理端鉴权"。


---

## 用户认证（Bearer）

App 端用户接口（11～12）使用 JWT 认证：

- 签发：注册/登录成功后返回 `token`；算法 HS256，有效期 30 天，claims 为 `sub`（用户 id）、`username`、`iat`、`exp`。
- 密钥：环境变量 `AUTH_SECRET`；未设置时使用开发默认值 `dev-auth-secret`（启动日志会提醒，生产环境必须设置）。
- 携带方式：请求头 `Authorization: Bearer <token>`；CORS 已放开 `Authorization` 头。
- 校验失败（缺失、非 Bearer 前缀、签名不对、过期、格式非法）一律 401：

```json
{"code": "AUTH_UNAUTHORIZED", "message": "missing bearer token", "data": null}
```

`message` 取值：`missing bearer token` / `invalid or expired token`。
密码仅存 bcrypt 哈希，任何响应都不包含明文密码或哈希。

---

## 11. POST /api/v1/auth/register

注册并直接返回 token（注册即登录）。

### 请求体

```json
{"username": "alice", "password": "secret123"}
```

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `username` | string | 是 | 3～32 字节，全局唯一 |
| `password` | string | 是 | 6～64 字节 |

### 成功响应 201

```json
{
  "code": "OK",
  "message": "ok",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {"id": 1, "username": "alice", "avatar": "", "createdAt": "2026-10-16T08:00:00Z"}
  }
}
```

### 失败响应

400（字段长度不合法或 body 非法 JSON）：

```json
{"code": "AUTH_INVALID_INPUT", "message": "username must be 3-32 bytes and password must be 6-64 bytes", "data": null}
```

409（用户名已存在）：

```json
{"code": "AUTH_USERNAME_TAKEN", "message": "username already exists", "data": null}
```

---

## 11b. POST /api/v1/auth/login

登录，成功返回与注册同构的 data。

### 请求体

同注册：`{"username": "...", "password": "..."}`（同样做长度校验，不合法返回 400 `AUTH_INVALID_INPUT`）。

### 成功响应 200

```json
{
  "code": "OK",
  "message": "ok",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {"id": 1, "username": "alice", "avatar": "", "createdAt": "2026-10-16T08:00:00Z"}
  }
}
```

### 失败响应 401（用户不存在或密码错误，不区分提示）

```json
{"code": "AUTH_INVALID_CREDENTIALS", "message": "invalid username or password", "data": null}
```

---

## 11c. GET /api/v1/auth/me（Bearer）

当前用户信息。

### 成功响应 200

```json
{
  "code": "OK",
  "message": "ok",
  "data": {"user": {"id": 1, "username": "alice", "avatar": "/avatars/1-ab12cd34.png", "createdAt": "2026-10-16T08:00:00Z"}}
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | int | 用户 id |
| `username` | string | 用户名 |
| `avatar` | string | 头像相对 URL（如 `/avatars/1-ab12cd34.png`），未上传时为空串 |
| `createdAt` | string | 注册时间（RFC3339 UTC） |

注册/登录返回的 `user` 对象同构（新用户 `avatar` 为空串）。

### 失败响应 401

未带 token / token 无效：`AUTH_UNAUTHORIZED`（见"用户认证（Bearer）"）。

---

## 12. 观看记录（Bearer）

用户在各课程的阅读进度记录，全部需要 `Authorization: Bearer <token>`；同一 `(用户, 课程, 章节)` 只保留一条，重复观看更新时间。

### 12a. PUT /api/v1/records

记录/刷新一次观看（upsert：存在则更新 `chapterTitle` 与 `readAt`）。

#### 请求体

```json
{"courseSlug": "go-basics", "chapterSlug": "hello-world", "chapterTitle": "Hello World"}
```

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `courseSlug` | string | 是 | 必须存在于 courses 表 |
| `chapterSlug` | string | 是 | 必须属于该课程（两条件任一不满足返回 404） |
| `chapterTitle` | string | 否 | 缺省时用章节表标题兜底 |

#### 成功响应 200

```json
{"code": "OK", "message": "ok", "data": {"ok": true}}
```

#### 失败响应

404（课程不存在、章节不存在或章节不属于该课程）：

```json
{"code": "NOT_FOUND", "message": "course or chapter not found", "data": null}
```

400（body 非法 JSON）：`AUTH_INVALID_INPUT`（`invalid request body`）。

### 12b. GET /api/v1/records

当前用户的观看记录，按 `readAt` 降序，最多 200 条。

#### 成功响应 200

```json
{
  "code": "OK",
  "message": "ok",
  "data": {
    "records": [
      {
        "courseSlug": "python-basics",
        "courseTitle": "Python 基础",
        "chapterSlug": "install-repl",
        "chapterTitle": "安装与 REPL",
        "readAt": "2026-10-16T09:00:00Z"
      },
      {
        "courseSlug": "go-basics",
        "courseTitle": "Go 语言入门",
        "chapterSlug": "hello-world",
        "chapterTitle": "Hello World",
        "readAt": "2026-10-16T07:30:00Z"
      }
    ]
  }
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `courseSlug` | string | 记录时的课程标识 |
| `courseTitle` | string | 来自 courses 表；课程已被删除时兜底为 `"(已删除课程)"` |
| `chapterSlug` | string | 章节标识 |
| `chapterTitle` | string | 记录时保存的标题 |
| `readAt` | string | 最近一次观看时间（RFC3339 UTC） |

### 12c. DELETE /api/v1/records/{courseSlug}/{chapterSlug}

删除当前用户的一条记录。

#### 参数

| 参数 | 位置 | 说明 |
| --- | --- | --- |
| `courseSlug` | path | 课程标识 |
| `chapterSlug` | path | 章节标识 |

#### 成功响应 200（n 为实际删除条数，0 表示本来就没有）

```json
{"code": "OK", "message": "ok", "data": {"deleted": 1}}
```

### 12d. DELETE /api/v1/records

清空当前用户全部记录。

#### 成功响应 200

```json
{"code": "OK", "message": "ok", "data": {"deleted": 5}}
```

---

## 13. App 版本

客户端检查更新与管理端版本维护。`GET /app/latest` 无认证；管理端接口走 `X-Admin-Token`（见"管理端鉴权"）。

### 13a. GET /api/v1/app/latest（无认证）

取 `enabled` 的版本中 `versionCode` 最大的一条。

#### 成功响应 200

```json
{
  "code": "OK",
  "message": "ok",
  "data": {
    "version": "1.2.0",
    "versionCode": 3,
    "notes": "修复若干问题，优化阅读体验。",
    "apkUrl": "https://example.com/app-1.2.0.apk",
    "force": true,
    "releasedAt": "2026-10-16T06:00:00Z"
  }
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `version` | string | 版本号（展示用） |
| `versionCode` | int | 递增整数，客户端据此判断新旧 |
| `notes` | string | 更新说明 |
| `apkUrl` | string | 安装包下载地址 |
| `force` | bool | 是否强制更新 |
| `releasedAt` | string | 发布时间（创建时间，RFC3339 UTC） |

#### 失败响应 404（无任何 enabled 版本）

```json
{"code": "NOT_FOUND", "message": "app release not found", "data": null}
```

### 13b. 管理端 App 版本 CRUD（X-Admin-Token）

- **GET /api/v1/admin/app-versions**：全部版本列表，按 `versionCode` 降序；data 为数组，元素含 `id`、`version`、`versionCode`、`notes`、`apkUrl`、`force`、`enabled`、`releasedAt`。
- **POST /api/v1/admin/app-versions**：创建版本（默认 `enabled=true`），成功 201 返回版本对象。

  请求体：

  ```json
  {"version": "1.3.0", "versionCode": 4, "notes": "新增离线缓存。", "apkUrl": "https://example.com/app-1.3.0.apk", "force": false}
  ```

- **PUT /api/v1/admin/app-versions/{id}**：更新全部字段，成功 200 返回更新后对象。

  请求体在创建基础上增加 `enabled`（可选，缺省保持原值；`force` 同样缺省保持原值）：

  ```json
  {"version": "1.3.0", "versionCode": 4, "notes": "新增离线缓存。", "apkUrl": "https://example.com/app-1.3.0.apk", "force": false, "enabled": false}
  ```

- **DELETE /api/v1/admin/app-versions/{id}**：删除版本，成功 200 `{"ok": true}`。

#### 失败响应（管理端 App 版本）

400（`version`/`apkUrl` 为空、`versionCode <= 0`，与现有管理端错误码风格一致）：

```json
{"code": "BAD_REQUEST", "message": "version is required", "data": null}
```

`message` 取值：`version is required` / `apkUrl is required` / `versionCode must be a positive integer`。

409（`versionCode` 与其他版本重复）：

```json
{"code": "VERSION_CONFLICT", "message": "versionCode already exists", "data": null}
```

404（id 不存在）：`{"code": "NOT_FOUND", "message": "app version not found", "data": null}`。

---

## 14. 用户头像

`POST /api/v1/me/avatar`（Bearer）上传头像；`GET /avatars/{filepath}` 静态取回（无需认证）。

### 14a. POST /api/v1/me/avatar（Bearer，multipart/form-data）

#### 请求

`multipart/form-data`，文件字段名 `file`：

```bash
curl -X POST http://localhost:8080/api/v1/me/avatar \
  -H "Authorization: Bearer <token>" \
  -F "file=@avatar.png"
```

#### 校验规则

- 文件字段必须存在；
- 大小 ≤ 5MB（读内容前按 multipart 头部判断）；
- 魔数只允许 JPEG（`FF D8 FF`）/ PNG（`89 50 4E 47`）/ WEBP（`RIFF....WEBP`）。

任一不满足返回 400：

```json
{"code": "AVATAR_INVALID", "message": "only JPEG, PNG or WEBP images are allowed", "data": null}
```

`message` 取值：`invalid multipart form` / `file field is required` / `file exceeds 5MB limit` / `cannot read uploaded file` / `only JPEG, PNG or WEBP images are allowed`。

#### 存储与替换

- 落盘目录 `backend/data/avatars/`（不存在时自动创建），文件名 `{userId}-{8位hex随机}.{jpg|png|webp}`，如 `3-ab12cd34.jpg`；
- 成功后更新 `users.avatar` 为相对 URL（如 `/avatars/3-ab12cd34.jpg`），并删除旧头像文件；
- 重复上传即替换。

#### 成功响应 200

```json
{
  "code": "OK",
  "message": "ok",
  "data": {
    "user": {"id": 1, "username": "alice", "avatar": "/avatars/1-ab12cd34.png", "createdAt": "2026-10-16T08:00:00Z"}
  }
}
```

#### 失败响应 401

未带 token / token 无效：`AUTH_UNAUTHORIZED`（见"用户认证（Bearer）"）。

### 14b. GET /avatars/{filepath}（无认证）

用户头像静态文件路由，行为与 `GET /images/{filepath}` 一致：`Content-Type` 按扩展名映射（`.png` → `image/png`、`.jpg` → `image/jpeg`、`.webp` → `image/webp`），文件不存在、`..` 越界统一 404 信封。目录不提供列表。

```bash
curl -s -o avatar.png http://localhost:8080/avatars/1-ab12cd34.png
```

---

## 15. 章节互动

章节级阅读量 / 点赞 / 评论。路径前缀 `/api/v1/courses/{slug}/chapters/{chapterSlug}`；课程不存在、章节不存在或章节不属于该课程时统一 404：

```json
{"code": "NOT_FOUND", "message": "course or chapter not found", "data": null}
```

### 15a. POST /api/v1/courses/{slug}/chapters/{chapterSlug}/view（无认证）

上报一次阅读，章节 `viewCount` 自增（仅更新该列，不改变章节 `updated_at`，因此不会抬升 `/meta` 的 `content_version`）。

#### 成功响应 200

```json
{"code": "OK", "message": "ok", "data": {"viewCount": 42}}
```

### 15b. GET /api/v1/courses/{slug}/chapters/{chapterSlug}/stats（可选 Bearer）

章节互动统计。无 token 或 token 无效均放行（匿名 `liked=false`）；带合法 token 时返回当前用户是否已点赞。

#### 成功响应 200

```json
{
  "code": "OK",
  "message": "ok",
  "data": {"viewCount": 42, "likeCount": 3, "commentCount": 5, "liked": true}
}
```

### 15c. POST / DELETE /api/v1/courses/{slug}/chapters/{chapterSlug}/like（Bearer）

点赞 / 取消点赞，均幂等（重复调用返回当前状态，不报错）。

#### 成功响应 200

```json
{"code": "OK", "message": "ok", "data": {"liked": true, "likeCount": 3}}
```

取消后：`{"liked": false, "likeCount": 2}`。

#### 失败响应 401

未带 token / token 无效：`AUTH_UNAUTHORIZED`。

### 15d. GET /api/v1/courses/{slug}/chapters/{chapterSlug}/comments（无认证，分页）

评论列表，最新在前（`createdAt` 降序，同秒按 `id` 降序）。

#### 参数

| 参数 | 位置 | 说明 |
| --- | --- | --- |
| `page` | query | 页码，≥1，默认 1；非法值回落 1 |
| `pageSize` | query | 每页条数，1～50，默认 20；越界回落边界内默认 |

#### 成功响应 200

```json
{
  "code": "OK",
  "message": "ok",
  "data": {
    "comments": [
      {
        "id": 2,
        "userId": 2,
        "username": "bob",
        "avatar": "/avatars/2-9f8e7d6c.jpg",
        "content": "写得不错！",
        "createdAt": "2026-10-16T09:30:00Z"
      }
    ],
    "total": 1,
    "page": 1,
    "pageSize": 20,
    "pageCount": 1
  }
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `comments` | array | 无评论时为 `[]`（不是 `null`） |
| `total` | int | 该章节评论总数 |
| `pageCount` | int | `ceil(total/pageSize)`，total=0 时为 0 |
| `avatar` | string | 作者当前头像相对 URL，可为 `""` |

### 15e. POST /api/v1/courses/{slug}/chapters/{chapterSlug}/comments（Bearer）

发布评论。

#### 请求体

```json
{"content": "写得不错！"}
```

`content` 去除首尾空白后长度须为 1～1000 个字符（rune 计），否则 400：

```json
{"code": "COMMENT_INVALID_INPUT", "message": "content must be 1-1000 characters after trimming", "data": null}
```

同一用户两次发布间隔不足 10 秒返回 429（进程内计时，服务重启后清零）：

```json
{"code": "COMMENT_TOO_FAST", "message": "commenting too fast, retry in 10s", "data": null}
```

#### 成功响应 201

```json
{
  "code": "OK",
  "message": "ok",
  "data": {
    "comment": {
      "id": 3,
      "userId": 1,
      "username": "alice",
      "avatar": "",
      "content": "写得不错！",
      "createdAt": "2026-10-16T09:31:00Z"
    }
  }
}
```

#### 失败响应 401

未带 token / token 无效：`AUTH_UNAUTHORIZED`。

### 15f. DELETE /api/v1/comments/{id}（Bearer）

删除评论，仅作者本人。

#### 参数

| 参数 | 位置 | 说明 |
| --- | --- | --- |
| `id` | path | 评论 id；不存在或 id 非数字返回 404 |

#### 成功响应 200

```json
{"code": "OK", "message": "ok", "data": {"deleted": 1}}
```

#### 失败响应

404（评论不存在）：

```json
{"code": "NOT_FOUND", "message": "comment not found", "data": null}
```

403（删除他人评论）：

```json
{"code": "COMMENT_FORBIDDEN", "message": "only the author can delete this comment", "data": null}
```

---

## 16. 管理端评论管理（X-Admin-Token）

### 16a. GET /api/v1/admin/comments?courseSlug=&page=&pageSize=

全部评论列表（跨章节），最新在前；`courseSlug` 为空表示全部课程；分页参数同 15d。

#### 成功响应 200

```json
{
  "code": "OK",
  "message": "ok",
  "data": {
    "comments": [
      {
        "id": 3,
        "userId": 1,
        "username": "alice",
        "courseSlug": "go-basics",
        "courseTitle": "Go 语言入门",
        "chapterSlug": "hello-world",
        "chapterTitle": "Hello World",
        "content": "写得不错！",
        "createdAt": "2026-10-16T09:31:00Z"
      }
    ],
    "total": 1,
    "page": 1,
    "pageSize": 20,
    "pageCount": 1
  }
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `courseTitle` | string | 联表自 courses；课程已被删除时兜底 `"(已删除课程)"` |
| `chapterTitle` | string | 联表自 chapters；章节已被删除时兜底 `"(已删除章节)"` |
| `username` | string | 联表自 users；作者已被删除时兜底 `"(已删除用户)"` |

### 16b. DELETE /api/v1/admin/comments/{id}

删除任意评论。

#### 成功响应 200

```json
{"code": "OK", "message": "ok", "data": {"deleted": 1}}
```

#### 失败响应 404

```json
{"code": "NOT_FOUND", "message": "comment not found", "data": null}
```

---

## 17. 管理端概况统计（X-Admin-Token）

### GET /api/v1/admin/stats

后台仪表盘概况：各表计数、总阅读量、内容版本与最新动态（热门章节、新注册用户、最新评论）。

#### 成功响应 200

```json
{
  "code": "OK",
  "message": "ok",
  "data": {
    "courseCount": 3,
    "chapterCount": 120,
    "totalViews": 4567,
    "userCount": 23,
    "commentCount": 45,
    "likeCount": 78,
    "contentVersion": "2026-10-15T10:30:58Z",
    "topChapters": [
      {"courseSlug": "go-basics", "courseTitle": "Go 语言入门", "chapterSlug": "hello-world", "chapterTitle": "Hello World", "viewCount": 123}
    ],
    "recentUsers": [
      {"id": 1, "username": "alice", "avatar": "", "createdAt": "2026-10-16T08:00:00Z"}
    ],
    "recentComments": [
      {"id": 3, "userId": 1, "username": "alice", "courseSlug": "go-basics", "chapterSlug": "hello-world", "chapterTitle": "Hello World", "content": "写得不错！", "createdAt": "2026-10-16T09:31:00Z"}
    ]
  }
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `courseCount` / `chapterCount` / `userCount` / `commentCount` / `likeCount` | int | courses / chapters / users / chapter_comments / chapter_likes 各表行数 |
| `totalViews` | int | 全部章节 `view_count` 之和，空表为 0 |
| `contentVersion` | string | 与 GET /meta 的 `content_version` 同语义：courses + chapters 两表最大 `updated_at`（RFC3339 UTC） |
| `topChapters` | array | `view_count > 0` 的章节按其降序前 5，联 courses 补 `courseSlug`/`courseTitle`；无则 `[]`（不是 `null`） |
| `recentUsers` | array | 最新注册用户前 5（`created_at DESC, id DESC`），字段同 11 的 `user` 对象（`id`/`username`/`avatar`/`createdAt`）；无则 `[]` |
| `recentComments` | array | 最新评论前 5（`created_at DESC, id DESC`），联 users / chapters 补用户名与章节标题；无则 `[]` |
| `recentComments[].username` | string | 作者已被删除时兜底 `"(已删除用户)"` |
| `recentComments[].chapterTitle` | string | 章节已被删除时兜底 `"(已删除章节)"` |

403：见"管理端鉴权"。

---

## 18. 管理端用户管理（18a 列表 / 18b 删除）

### 18a. GET /api/v1/admin/users?page=&pageSize=&q=

全部用户列表，最新在前（`created_at DESC, id DESC`）；分页参数同 15d（`page` ≥1 默认 1、`pageSize` 1～50 默认 20，越界回落）；`q` 可选，对 `username` 做 `LIKE '%q%'` 模糊过滤（为空表示全部）。

#### 成功响应 200

```json
{
  "code": "OK",
  "message": "ok",
  "data": {
    "users": [
      {
        "id": 1,
        "username": "alice",
        "avatar": "",
        "createdAt": "2026-10-16T08:00:00Z",
        "commentCount": 5,
        "likeCount": 3,
        "recordCount": 10,
        "lastReadAt": "2026-10-19T10:00:00Z"
      }
    ],
    "total": 23,
    "page": 1,
    "pageSize": 20,
    "pageCount": 2
  }
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `users` | array | 无用户时为 `[]`（不是 `null`） |
| `total` | int | 符合过滤条件的用户总数 |
| `pageCount` | int | `ceil(total/pageSize)`，total=0 时为 0 |
| `avatar` | string | 用户当前头像相对 URL（如 `/avatars/1-ab12cd34.png`），未上传时为空串 |
| `createdAt` | string | 注册时间（RFC3339 UTC） |
| `commentCount` / `likeCount` / `recordCount` | int | 该用户在 chapter_comments / chapter_likes / reading_records 的行数 |
| `lastReadAt` | string | 该用户 reading_records 的 `MAX(read_at)`（RFC3339 UTC），无记录时为 `""` |

### 18b. DELETE /api/v1/admin/users/{id}

删除用户，并在单事务内连同其全部评论、点赞与观看记录一起删除；事务提交后尽力删除其头像文件（删除失败仅记日志，不影响响应）。

#### 参数

| 参数 | 位置 | 说明 |
| --- | --- | --- |
| `id` | path | 用户 id；非数字、为 0 或不存在均返回 404 |

#### 成功响应 200

```json
{"code": "OK", "message": "ok", "data": {"deleted": true}}
```

#### 失败响应 404

```json
{"code": "NOT_FOUND", "message": "user not found", "data": null}
```

403：见"管理端鉴权"。

---

## 错误码汇总

| HTTP | code | 场景 |
| --- | --- | --- |
| 200/201 | `OK` | 成功（201 仅注册、发布评论、管理端创建 App 版本） |
| 400 | `BAD_REQUEST` | 管理端：请求体非法 JSON（`invalid request body`）、缺 slug/`slug is required`、缺 title/`title is required`、color 非法（`invalid color: want #RRGGBB`）、课程 slug 重复（`course slug already exists`）、章节 slug 重复（`chapter slug already exists`）、App 版本入参不合法（`version is required` / `apkUrl is required` / `versionCode must be a positive integer`） |
| 400 | `AUTH_INVALID_INPUT` | 用户端：注册/登录字段长度不合法（`username must be 3-32 bytes and password must be 6-64 bytes`）、请求体非法 JSON（`invalid request body`） |
| 400 | `AVATAR_INVALID` | 头像上传：multipart 非法、缺 file 字段、超 5MB、非 JPEG/PNG/WEBP 魔数（见 14a） |
| 400 | `COMMENT_INVALID_INPUT` | 发布评论：content 去空白后为空或超过 1000 字符（`content must be 1-1000 characters after trimming`） |
| 400 | `IMPORT_BAD_ZIP` | 课程包导入（10b）：非 zip/损坏/条目数或解压大小超限/路径不安全（绝对路径、`..`、盘符）/意外条目/请求体超 600MB |
| 400 | `IMPORT_INVALID_PACKAGE` | 课程包导入（10b）：courses.json 缺失或非法（不可解析、courses 空、slug/title 缺失、chapters 空、sort_order < 1） |
| 400 | `IMPORT_MISSING_FILES` | 课程包导入（10b）：courses.json 引用的章节 md 不在 zip 根（最多列 10 个文件名） |
| 401 | `AUTH_UNAUTHORIZED` | 用户端：Bearer token 缺失（`missing bearer token`）或无效/过期（`invalid or expired token`） |
| 401 | `AUTH_INVALID_CREDENTIALS` | 登录：用户不存在或密码错误（`invalid username or password`） |
| 403 | `FORBIDDEN` | 管理端：`ADMIN_TOKEN` 未设置（`admin disabled: ADMIN_TOKEN not set`）或 token 不匹配（`invalid admin token`） |
| 403 | `COMMENT_FORBIDDEN` | 删除他人评论（`only the author can delete this comment`） |
| 404 | `NOT_FOUND` | 路径不存在、课程不存在（`course not found`）、章节不存在（`chapter not found`）、观看记录/章节互动的课程章节校验失败（`course or chapter not found`）、评论不存在（`comment not found`）、用户不存在（`user not found`，18b）、无可用 App 版本（`app release not found`）、App 版本 id 不存在（`app version not found`） |
| 409 | `AUTH_USERNAME_TAKEN` | 注册：用户名已存在（`username already exists`） |
| 409 | `VERSION_CONFLICT` | 管理端：versionCode 与其他版本重复（`versionCode already exists`） |
| 429 | `COMMENT_TOO_FAST` | 发布评论：同一用户两次发布间隔 <10s（`commenting too fast, retry in 10s`） |
| 500 | `INTERNAL` | 服务器内部错误（`internal error`） |

## 数据模型

- **courses**：`ID`、`Slug`（唯一）、`Title`、`Summary`、`Language`、`Color`、`SortOrder`、`CreatedAt`、`UpdatedAt`
- **chapters**：`ID`、`CourseID`（外键，联合唯一首列 + 可作单列索引前缀）、`Slug`（联合唯一 `idx_chapters_course_slug(CourseID, Slug)`）、`Title`、`ContentMD`（markdown 正文）、`SortOrder`、`ViewCount`（阅读量，view 接口自增且不抬 `UpdatedAt`）、`CreatedAt`、`UpdatedAt`
- **users**：`ID`、`Username`（唯一，3～32 字节）、`PasswordHash`（bcrypt，永不出库）、`Avatar`（头像相对 URL，空串=无头像）、`CreatedAt`、`UpdatedAt`
- **reading_records**：`ID`、`UserID`（索引）、`CourseSlug`、`ChapterSlug`（联合唯一 `idx_records_user_chapter(UserID, CourseSlug, ChapterSlug)`）、`ChapterTitle`、`ReadAt`（最近观看时间）
- **chapter_comments**：`ID`、`UserID`（索引）、`CourseSlug`、`ChapterSlug`（联合索引 `idx_comments_chapter(CourseSlug, ChapterSlug)`）、`Content`（≤2000 字节）、`CreatedAt`、`UpdatedAt`
- **chapter_likes**：`ID`、`UserID`、`CourseSlug`、`ChapterSlug`（三元联合唯一 `idx_likes_user_chapter(UserID, CourseSlug, ChapterSlug)`，点赞幂等）、`CreatedAt`
- **app_releases**：`ID`、`Version`、`VersionCode`（唯一，正整数）、`Notes`、`ApkURL`、`Force`、`Enabled`（latest 仅取 enabled 中 versionCode 最大者）、`CreatedAt`（对外的 `releasedAt`）、`UpdatedAt`

表结构由 GORM AutoMigrate 自动创建。

---

## 教程图片静态托管：GET /images/{filepath}

教程图片静态文件路由（离线下载功能配套，无需认证）。教程正文中的图片以相对路径引用（如 `images/hello-algo/sorting/quick_sort.assets/pivot_division_step1.png`），客户端拼上服务器地址后经此路由获取文件。

- 服务端根目录：`backend/static/images/`（相对后端进程工作目录）。目录**不存在时不预创建**，此时请求一律 404；目录后续落盘后无需重启即可生效。
- 参数：`filepath` 为 path 通配，即图片在 `static/images/` 下的相对路径，支持多级子目录（与正文中的相对路径一一对应）。
- 认证：无（与 /api/v1 内容读接口同级）；`Access-Control-Allow-Origin: *` 同样适用。

### 成功响应 200

返回文件二进制内容，`Content-Type` 按扩展名自动映射（`.png` → `image/png`、`.jpg`/`.jpeg` → `image/jpeg`、`.gif` → `image/gif`、`.svg` → `image/svg+xml`、`.webp` → `image/webp`、`.mp4` → `video/mp4` 等）。

```bash
curl -s -o pivot.png http://localhost:8080/images/hello-algo/sorting/quick_sort.assets/pivot_division_step1.png
```

### 失败响应 404

文件不存在、图片目录未落盘或路径越界（含 `..` 穿越，不可越出图片根目录）时返回统一 JSON 信封：

```json
{"code": "NOT_FOUND", "message": "not found", "data": null}
```

> 目录请求（如 `GET /images/`）与目录列表均被禁用，同样返回 404，不暴露文件清单。
