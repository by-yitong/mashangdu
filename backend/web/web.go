// Package web 在编译期通过 go:embed 嵌入后台管理前端（React SPA）的静态
// 产物，使 /admin 与 API 永远同源，二进制单独部署即可用，运行时不依赖磁盘
// 上的 admin/dist 目录。
//
// 构建流程：先在仓库根 admin/ 执行 npm run build，再把构建产物覆盖拷贝到
// backend/web/dist/，最后在 backend/ 下 go build ./...。未跑前端构建时
// dist 仅含占位 index.html（见 .gitignore 保留规则），go build 依旧通过。
package web

import "embed"

// DistFS 嵌入 backend/web/dist 的全部内容（含点/下划线开头文件）。
// dist 位于嵌入 FS 的根：DistFS.ReadFile("dist/index.html") 直接可用。
//
//go:embed all:dist
var DistFS embed.FS
