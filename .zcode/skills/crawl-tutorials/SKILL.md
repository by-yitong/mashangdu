---
name: crawl-tutorials
description: 从教程网站/开源文档仓库抓取内容，转成课程包（zip），经管理端导入接口动态上线。内容永不进二进制。
---

# Skill: crawl-tutorials（教程爬取入库）

从教程网站/开源文档仓库抓取内容，转成课程包并动态导入线上环境。本项目（code-tutorials）的既有战例：hello-algo.com 全本 117 章（mkdocs）、TRPL 中文版（mdBook）、jetpackcompose.cn《你好 Compose》58 章（docusaurus）。

## 一键用法（目标形态）

用户说「爬取 <URL> 并上线」→ 按本 skill 走完全部步骤（法律红线检查 → 侦察 → 转换 → 本地验证 → 打包 → 导入线上）→ 汇报章节数/图片体量/导入结果。全程不需要用户再介入，除非：源站无 License（第 1 步红线，停下问用户）或缺 admin token（见下）。

**唯一配置项——线上 admin token**：导入接口需要 `X-Admin-Token`。约定按序查找：
1. 环境变量 `CT_ADMIN_TOKEN`
2. 文件 `.zcode/skills/crawl-tutorials/token.local`（一行纯 token，已 gitignore）

都没有 → 问用户要一次并存入 token.local，之后的会话全自动。**默认导入目标 `http://103.117.137.83:8091`**（直连后端端口；nginx 域名 studio.phpcurl.cn 若走需先确认 client_max_body_size ≥ 600MB，默认 1MB 会 413）。

---

## 第 0 步：架构红线（最高优先级）

- **课程内容是运行时数据，绝不编译进二进制**：`backend/internal/store/store.go` 没有 `go:embed seeddata`。内容只存在于磁盘 `seeddata/`（md + courses.json）与 `static/images/`，后端启动时按 slug upsert 进库（从不删除）。
- **上线内容 = 导入课程包**：`POST /api/v1/admin/courses/import`（zip），零编译、零重启、零 ssh。
- **ssh 部署脚本（scripts/deploy-prod.sh）只用于代码变更**，不要为加课程跑它。

## 第 1 步：法律红线（不可跳过）

1. **先查 LICENSE**：站点页脚、GitHub 仓库 LICENSE。常见结论：
   - `CC BY-NC-SA`（hello-algo 4.0、你好 Compose 2.0）：可转载，**必须每章署名**，禁止商用，改编同许可。
   - `CC BY 4.0` / MIT / Apache：可转载，保留署名。
   - 无 License / 全保留版权：**不要爬**，告知用户风险。
2. 署名模板（每章 md 末尾）：
   `> 本文来自 [站名](源站URL)，作者 X，采用 <LICENSE> 授权转载。`

## 第 2 步：侦察（产出"源结构清单"）

能用原始 md 就绝不抓 HTML：

| 优先级 | 内容源 | 判断 |
|---|---|---|
| 1 | 站点对应 GitHub 仓库的 md 源 | 页脚 "Edit on GitHub"；docusaurus/mkdocs/vitepress 站几乎都有 |
| 2 | 导航配置 | mkdocs: `mkdocs.yml` nav；docusaurus: `sidebars.js`；vitepress: `.vitepress/config.*` |
| 3 | sitemap.xml + HTML→MD | 无仓库时保底 |

**无 md 源的普通网站（HTML 抓取）**：先用 sitemap.xml 或目录页枚举全部教程页 URL；为该站写一次性 python 脚本（放 `tools/`，命名 `<站点名>_to_seed.py`，stdlib-only + urllib）：逐页抓 HTML → 定位正文容器（找章节正文共同的 class/id，抽查 2~3 页确认）→ HTML 转 md（标题/段落/代码块/图片/链接保留，广告导航脚注丢弃）→ 套用第 3 步契约输出。围栏感知转换规则同样适用。UA + 重试 + 幂等照旧。

侦察要点（逐项实测，不臆猜）：nav 文件拉下来确认目录顺序；源文件真实路径 curl 探测 200 再定（docs_dir 可能指向构建产物）；抽查 2~3 个源文件记录语法特征（frontmatter/H1/标签页/警告框/图片引用方式）；图片优先本地化（国内手机直连外网 CDN 不可靠，见实战经验）。

## 第 3 步：转换契约（派卡前冻结）

### 通用必做转换

| 源语法 | 处理 |
|---|---|
| frontmatter `--- ... ---` | 删除；title 进 courses.json |
| 正文第一个 H1 | 删除 |
| 语言/选项标签页 | 拍平：去缩进、去围栏属性，每块前加 `**标签**` 加粗行 |
| 警告框（mkdocs `!!!`/docusaurus `:::type`） | 转块引用 `> **标题**` + `> ` 前缀 |
| 包含指令（`--8<--` 等） | 递归取内容（深度≤3），取不到删行+告警 |
| 相对图片 | 下载到 `backend/static/images/<课程slug>/<章slug>/`，md 改写为 `images/<课程slug>/...` 相对路径（自托管，别赌外网 CDN） |
| 原生 HTML / mermaid / iframe | 删除或降级（iframe → `> 🎬 在线视频：[观看](URL)`）；HTML 行内标签映射（b→**、code→` 等） |
| 数学公式 | 保留原样 |

### slug / title / 顺序

- slug = `{章短名}-{文件stem}`，章短名映射表写进任务卡，**禁止运行时发明**（seed 按 slug upsert 且从不删除，slug 漂移会留孤儿章节）。特殊字符（`&`、大写）显式映射。
- title：frontmatter > nav 标题 > 正文 H1。
- sort_order：nav 顺序全局递增。
- 幂等：重跑 md 按 slug 覆盖、courses.json 按 slug 原位替换，sha256 一致。

### courses.json 条目

```json
{
  "slug": "hello-algo", "title": "Hello 算法", "summary": "……。内容来自 X（源站），遵循 <LICENSE> 授权转载。",
  "language": "Python/Go", "color": "#059669", "sort_order": 5,
  "chapters": [{"slug": "...", "title": "...", "sort_order": N, "file": "{slug}.md"}]
}
```

color 用青蓝/emerald 系，**禁止紫色、琥珀/橙黄**（用户不喜）。file 字段 = seeddata 下 md 文件名。

## 第 4 步：执行（主 agent 决策，子 agent 执行）

1. 主 agent 把契约 + 侦察清单写进自足任务卡，派一个 general-purpose 子 agent（不得再派生）。
2. 卡里必含：仓库路径、nav 权威清单、已验证的文件特征、转换契约逐条、slug 映射表、课程条目、自检标准、禁止事项（只许碰 seeddata/、static/images/、tools/）。
3. 可复用存量脚本（**在仓库 tools/ 里，别重写**）：`mkdocs_course_to_seed.py`、`mdbook_trpl_to_seed.py`、`docusaurus_course_to_seed.py`。按目标站点特征改参数/规则，不是无脑直跑。

## 第 5 步：落库与上线（新架构）

1. **本地落盘**（磁盘是唯一源，git 提交）：
   - md + courses.json → `backend/internal/store/seeddata/`
   - 图片 → `backend/static/images/<课程slug>/`
2. **本地验证**：
   - `cd backend && go test ./...`（store 测试会加载磁盘 seed）
   - 起本地后端（`ADMIN_TOKEN=dev123 ./backend.exe`）抽查 `GET /api/v1/courses/<slug>` 章节数、正文长度、图片 200
3. **打包**：`python tools/pack_course.py --slug <课程slug>` → `dist/<slug>.zip`
   （zip 布局 = 导入契约：根目录 `courses.json` 单条目 + `*.md` + `images/<slug>/**`；确定性打包，重跑 sha256 一致）
4. **上线**（二选一，token 见「一键用法」）：
   - `curl -s -H "X-Admin-Token: $TOKEN" -F file=@dist/<slug>.zip http://103.117.137.83:8091/api/v1/admin/courses/import`
   - 或管理后台 `/admin` →「课程导入」上传 zip（人工兜底）
5. **校验响应**：`data.courses[].chapters` 数与预期一致、state=created/updated；App 下拉刷新即可见（meta 的 content_version 变化）。失败错误码：`IMPORT_BAD_ZIP` / `IMPORT_INVALID_PACKAGE` / `IMPORT_MISSING_FILES`。

## 验收清单（主 agent 亲自跑）

```bash
# 1. JSON 合法 + 章节数 + 无重复 slug
python -c "import json;d=json.load(open('backend/internal/store/seeddata/courses.json',encoding='utf-8'));print([(c['slug'],len(c['chapters'])) for c in d['courses']])"
# 2. 源语法零残留（应无输出；围栏内代码除外，用围栏感知扫描）
grep -rl ':::\|@site\|<img \|<Tab\|<iframe\|](../' backend/internal/store/seeddata/<新slug>-*.md
# 3. 后端测试
cd backend && go test ./...
# 4. 导入线上后 API 抽查：课程目录顺序 + 任一章节正文长度 + 署名行 + 一张图 200
```

人工抽读 1~2 章：代码块完整、图片相对路径、无标签页残留、署名在末尾。

## 实战经验

- `docs_dir: build/docs` 是坑：构建目录仓库里不存在，raw 源在 `docs/`，404 探测再定。
- **PC 能通 ≠ 手机能通**：PC 挂 TUN 代理时 curl 验证 CDN 全绿但国内手机直连被墙。图片必须自托管。
- 导航是权威：章节数预估常不准（hello-algo 估 60~100 实际 117），全量为准不裁剪；nav 大小写与磁盘文件名可能不一致（compose 的 `animateAsState` ↔ `animatestate.mdx`），以磁盘为准。
- md 输出 UTF-8 无 BOM、LF；下载设 UA + 重试；外链图片 404 可回退 `web.archive.org/web/<id>_/` 快照（你好 Compose 的 17 个 Google GIF 即此取回）。
- **代码围栏的 info string 只留语言 token**：docusaurus 的 ` ```kotlin title="X.kt" ` 整串会被 App 当语言名，高亮失效。
- docusaurus 特征：图片走 `import x from '@site/static/img/...'` + `<img src={x}/>` JSX，源图在 `static/img/`；`<Tabs>/<TabItem>`、`:::type`、bilibili iframe。转换必须围栏感知（Kotlin 代码里的 `import`/泛型 `<T>` 不能误伤）。
- 动图 GIF 体积大（你好 Compose 63 个 GIF 73MB）：UI 教程的动图价值高，默认全量自托管，但要在汇报里给出体量让用户决定是否裁剪。
- seed upsert 从不删除：课程下线不能靠删文件，需要管理端删除能力（当前没有，别承诺）。
