package api

// 管理端课程包导入接口：POST /api/v1/admin/courses/import。
//
// 课程内容是运行时数据（不随二进制发布）：管理端上传课程包 zip，解压 md 与
// 图片落盘到 seedDir / imagesRoot，按 slug 原位替换/追加合并 courses.json，
// 随即 upsert 进数据库，无需重启服务。
//
// zip 布局（根目录）：
//   - courses.json（必需）：{"courses":[课程条目,...]}，条目字段与磁盘种子格式一致
//   - *.md（必需覆盖全部章节）：章节正文，文件名与 chapters[].file 一致，位于根
//   - images/**（可选）：图片，解压到图片根目录下
//
// 校验与限额：仅常规文件；条目数 ≤ 5000、总解压大小 ≤ 1GB、单文件 ≤ 200MB
//（entry 头 UncompressedSize64 预检 + 解压时累计复检）；路径拒绝绝对路径、
// `..`、盘符；根下只允许 courses.json / *.md / images/**。
//
// 错误码：400 IMPORT_BAD_ZIP（非 zip/损坏/超限/路径不安全/意外条目）、
// 400 IMPORT_INVALID_PACKAGE（courses.json 缺失或非法）、400 IMPORT_MISSING_FILES
//（章节 md 缺失）；鉴权由 adminAuth 中间件处理。

import (
	"archive/zip"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/gin-gonic/gin"

	"code-tutorials/backend/internal/model"
	"code-tutorials/backend/internal/store"
)

// 课程包导入限额。
const (
	importMaxBodyBytes  = 600 << 20 // 请求体上限 600MB
	importMaxEntries    = 5000      // zip 条目数上限
	importMaxTotalBytes = 1 << 30   // 解压总大小上限 1GB
	importMaxFileBytes  = 200 << 20 // 单文件解压大小上限 200MB
	// importMaxMissingList 缺失章节文件名最多列出的个数。
	importMaxMissingList = 10
)

// importCoursesFile 课程包与磁盘种子共用的 courses.json 结构（schema 冻结）。
type importCoursesFile struct {
	Courses []importCourse `json:"courses"`
}

// importCourse 课程条目，字段与磁盘种子 courses.json 完全一致。
type importCourse struct {
	Slug      string          `json:"slug"`
	Title     string          `json:"title"`
	Summary   string          `json:"summary"`
	Language  string          `json:"language"`
	Color     string          `json:"color"`
	SortOrder int             `json:"sort_order"`
	Chapters  []importChapter `json:"chapters"`
}

// importChapter 章节条目；file 为 zip 根下的 md 文件名。
type importChapter struct {
	Slug      string `json:"slug"`
	Title     string `json:"title"`
	SortOrder int    `json:"sort_order"`
	File      string `json:"file"`
}

// importPackage 第一遍扫描（仅元数据）得到的 zip 概貌。
type importPackage struct {
	jsonRaw []byte          // 根下 courses.json 原文
	rootMDs map[string]bool // 根下 *.md 文件名集合
}

// importImageStats 本次实际解压的图片统计。
type importImageStats struct {
	Count int   `json:"count"`
	Bytes int64 `json:"bytes"`
}

// importCourseResult 单门课程的导入结果。
type importCourseResult struct {
	Slug     string `json:"slug"`
	Title    string `json:"title"`
	Chapters int    `json:"chapters"`
	State    string `json:"state"` // created | updated
}

// importFailure 导入校验失败：携带统一信封的错误码与消息。实现 error；
// 各校验函数一律以 error 接口返回，避免 typed nil 被装箱成非 nil 接口。
type importFailure struct {
	code    string
	message string
}

func (e *importFailure) Error() string { return e.message }

func importFail(code, message string) *importFailure {
	return &importFailure{code: code, message: message}
}

// POST /api/v1/admin/courses/import（multipart/form-data，字段 file = zip）。
func (s *Server) importCourses(c *gin.Context) {
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, importMaxBodyBytes)
	pkg, zr, closeFn, err := scanImportZip(c)
	if err != nil {
		s.failImport(c, err)
		return
	}
	defer closeFn()

	incoming, err := validateImportCoursesJSON(pkg.jsonRaw, pkg.rootMDs)
	if err != nil {
		s.failImport(c, err)
		return
	}

	// 落盘前查询各 slug 在 DB 中的存在性（决定响应里的 created/updated）。
	existing := map[string]bool{}
	var slugs []string
	for _, course := range incoming {
		slugs = append(slugs, course.Slug)
	}
	if len(slugs) > 0 {
		var found []string
		if err := s.db.Model(&model.Course{}).Where("slug IN ?", slugs).Pluck("slug", &found).Error; err != nil {
			s.internalError(c, err)
			return
		}
		for _, slug := range found {
			existing[slug] = true
		}
	}

	// 第二遍：解压落盘（md → seedDir，images/** → imagesRoot）。
	images, err := extractImportZip(zr, pkg, s.seedDir, s.imagesRoot)
	if err != nil {
		s.failImport(c, err)
		return
	}

	// 合并 courses.json：按 slug 原位替换/追加，原子写回（MarshalIndent 两空格）。
	merged, err := mergeImportCourses(s.seedDir, incoming)
	if err != nil {
		s.internalError(c, err)
		return
	}
	if err := writeCoursesJSONAtomic(s.seedDir, merged); err != nil {
		s.internalError(c, err)
		return
	}

	// 立即 upsert 进 DB（无需重启服务）。
	if err := store.UpsertCoursesJSON(s.db, s.seedDir, filepath.Join(s.seedDir, "courses.json")); err != nil {
		s.internalError(c, err)
		return
	}

	results := make([]importCourseResult, 0, len(incoming))
	for _, course := range incoming {
		state := "created"
		if existing[course.Slug] {
			state = "updated"
		}
		results = append(results, importCourseResult{
			Slug:     course.Slug,
			Title:    course.Title,
			Chapters: len(course.Chapters),
			State:    state,
		})
	}
	ok(c, gin.H{"courses": results, "images": images})
}

// failImport 把 importFailure 写成统一信封（一律 400，错误码由 importFailure
// 携带）；非 importFailure 的错误按 zip 损坏兜底（校验路径实际只产生
// importFailure）。
func (s *Server) failImport(c *gin.Context, err error) {
	var failure *importFailure
	if errors.As(err, &failure) {
		fail(c, http.StatusBadRequest, failure.code, failure.message)
		return
	}
	fail(c, http.StatusBadRequest, "IMPORT_BAD_ZIP", err.Error())
}

// scanImportZip 解析 multipart 字段 file 并做第一遍元数据扫描：路径安全、
// 根目录白名单、条目数与解压大小预检，读出 courses.json 原文与 md 名单。
// 返回的 zip.Reader 供第二遍解压复用；closeFn 关闭底层 multipart 文件。
func scanImportZip(c *gin.Context) (*importPackage, *zip.Reader, func(), error) {
	closeFn := func() {}
	fileHeader, err := c.FormFile("file")
	if err != nil {
		var maxErr *http.MaxBytesError
		if errors.As(err, &maxErr) {
			return nil, nil, closeFn, importFail("IMPORT_BAD_ZIP", "request body exceeds 600MB limit")
		}
		return nil, nil, closeFn, importFail("IMPORT_BAD_ZIP", "multipart field 'file' is required")
	}
	f, err := fileHeader.Open()
	if err != nil {
		return nil, nil, closeFn, importFail("IMPORT_BAD_ZIP", "cannot open uploaded file")
	}
	closeFn = func() { _ = f.Close() }

	zr, err := zip.NewReader(f, fileHeader.Size)
	if err != nil {
		return nil, nil, closeFn, importFail("IMPORT_BAD_ZIP", "invalid or corrupted zip file")
	}

	pkg := &importPackage{rootMDs: map[string]bool{}}
	var declaredTotal uint64
	entries := 0
	for _, entry := range zr.File {
		entries++
		if entries > importMaxEntries {
			return nil, nil, closeFn, importFail("IMPORT_BAD_ZIP",
				fmt.Sprintf("too many zip entries (more than %d)", importMaxEntries))
		}
		name, err := safeZipEntryName(entry.Name)
		if err != nil {
			return nil, nil, closeFn, err
		}
		if !entry.FileInfo().Mode().IsRegular() {
			return nil, nil, closeFn, importFail("IMPORT_BAD_ZIP",
				fmt.Sprintf("zip entry is not a regular file: %s", name))
		}
		if size := entry.UncompressedSize64; size > importMaxFileBytes {
			return nil, nil, closeFn, importFail("IMPORT_BAD_ZIP",
				fmt.Sprintf("zip entry %s exceeds 200MB uncompressed size limit", name))
		}
		declaredTotal += entry.UncompressedSize64
		if declaredTotal > importMaxTotalBytes {
			return nil, nil, closeFn, importFail("IMPORT_BAD_ZIP",
				"total uncompressed size exceeds 1GB limit")
		}

		switch {
		case name == "courses.json":
			raw, err := readZipEntry(entry)
			if err != nil {
				return nil, nil, closeFn, err
			}
			pkg.jsonRaw = raw
		case strings.HasSuffix(name, ".md") && !strings.Contains(name, "/"):
			pkg.rootMDs[name] = true
		case strings.HasPrefix(name, "images/") && len(name) > len("images/"):
			// 图片条目：解压阶段按名字归类落盘，此处无需记录。
		default:
			return nil, nil, closeFn, importFail("IMPORT_BAD_ZIP",
				fmt.Sprintf("unexpected zip entry (only courses.json, *.md at root and images/** are allowed): %s", name))
		}
	}
	if pkg.jsonRaw == nil {
		return nil, nil, closeFn, importFail("IMPORT_INVALID_PACKAGE", "courses.json missing from package")
	}
	return pkg, zr, closeFn, nil
}

// safeZipEntryName 校验并归一条目名：分隔符归一为 /、拒绝绝对路径、`..` 段
// 与 Windows 盘符；返回归一后的名字。
func safeZipEntryName(name string) (string, error) {
	normalized := strings.ReplaceAll(name, "\\", "/")
	if normalized == "" {
		return "", importFail("IMPORT_BAD_ZIP", "empty zip entry name")
	}
	if strings.HasPrefix(normalized, "/") {
		return "", importFail("IMPORT_BAD_ZIP",
			fmt.Sprintf("absolute path in zip is not allowed: %s", name))
	}
	// 盘符（如 C:/evil.md 或 C:\evil.md）。
	if len(normalized) >= 2 && normalized[1] == ':' &&
		(normalized[0] >= 'a' && normalized[0] <= 'z' || normalized[0] >= 'A' && normalized[0] <= 'Z') {
		return "", importFail("IMPORT_BAD_ZIP",
			fmt.Sprintf("drive-letter path in zip is not allowed: %s", name))
	}
	for _, seg := range strings.Split(normalized, "/") {
		if seg == ".." {
			return "", importFail("IMPORT_BAD_ZIP",
				fmt.Sprintf("path traversal in zip is not allowed: %s", name))
		}
	}
	return normalized, nil
}

// readZipEntry 读取单个条目内容（受单文件限额约束）。
func readZipEntry(entry *zip.File) ([]byte, error) {
	rc, err := entry.Open()
	if err != nil {
		return nil, importFail("IMPORT_BAD_ZIP",
			fmt.Sprintf("cannot read zip entry %s", entry.Name))
	}
	defer rc.Close()
	raw, err := io.ReadAll(io.LimitReader(rc, importMaxFileBytes+1))
	if err != nil {
		return nil, importFail("IMPORT_BAD_ZIP",
			fmt.Sprintf("corrupted zip entry %s: %v", entry.Name, err))
	}
	if int64(len(raw)) > importMaxFileBytes {
		return nil, importFail("IMPORT_BAD_ZIP",
			fmt.Sprintf("zip entry %s exceeds 200MB limit", entry.Name))
	}
	return raw, nil
}

// validateImportCoursesJSON 校验包内 courses.json：可解析、courses 非空、
// 每门课 slug/title 必填且 chapters 非空、每章 slug/title 必填、sort_order ≥ 1、
// file 必须存在于 zip 根（缺失最多列 10 个文件名）。
func validateImportCoursesJSON(raw []byte, rootMDs map[string]bool) ([]importCourse, error) {
	badPackage := func(format string, args ...interface{}) error {
		return importFail("IMPORT_INVALID_PACKAGE", fmt.Sprintf("invalid courses.json: "+format, args...))
	}
	var payload importCoursesFile
	if err := json.Unmarshal(raw, &payload); err != nil {
		return nil, badPackage("%v", err)
	}
	if len(payload.Courses) == 0 {
		return nil, badPackage("courses array is empty")
	}
	var missing []string
	for i, course := range payload.Courses {
		if strings.TrimSpace(course.Slug) == "" {
			return nil, badPackage("courses[%d].slug is required", i)
		}
		if strings.TrimSpace(course.Title) == "" {
			return nil, badPackage("courses[%d] (%s) title is required", i, course.Slug)
		}
		if len(course.Chapters) == 0 {
			return nil, badPackage("courses[%d] (%s) has no chapters", i, course.Slug)
		}
		for j, chapter := range course.Chapters {
			if strings.TrimSpace(chapter.Slug) == "" {
				return nil, badPackage("courses[%d].chapters[%d].slug is required", i, j)
			}
			if strings.TrimSpace(chapter.Title) == "" {
				return nil, badPackage("courses[%d].chapters[%d] (%s) title is required", i, j, chapter.Slug)
			}
			if chapter.SortOrder < 1 {
				return nil, badPackage("courses[%d].chapters[%d] (%s) sort_order must be >= 1, got %d",
					i, j, chapter.Slug, chapter.SortOrder)
			}
			if !rootMDs[chapter.File] && len(missing) < importMaxMissingList {
				missing = append(missing, chapter.File)
			}
		}
	}
	if len(missing) > 0 {
		return nil, importFail("IMPORT_MISSING_FILES",
			fmt.Sprintf("chapter md files missing from zip: %s", strings.Join(missing, ", ")))
	}
	return payload.Courses, nil
}

// extractImportZip 第二遍扫描：把 md 写入 seedDir、images/** 写入 imagesRoot
// （同名覆盖），解压时按实际字节数累计复检单文件与总大小限额（防 header 谎报）。
func extractImportZip(zr *zip.Reader, pkg *importPackage, seedDir, imagesRoot string) (importImageStats, error) {
	stats := importImageStats{}
	if err := os.MkdirAll(seedDir, 0o755); err != nil {
		return stats, fmt.Errorf("create seed dir: %w", err)
	}
	var writtenTotal int64
	for _, entry := range zr.File {
		name, err := safeZipEntryName(entry.Name)
		if err != nil {
			return stats, err
		}
		var dest string
		isImage := false
		switch {
		case name == "courses.json":
			continue // 走合并逻辑，不直接覆盖
		case strings.HasSuffix(name, ".md") && !strings.Contains(name, "/"):
			dest = filepath.Join(seedDir, filepath.FromSlash(name))
		case strings.HasPrefix(name, "images/") && len(name) > len("images/"):
			dest = filepath.Join(imagesRoot, filepath.FromSlash(strings.TrimPrefix(name, "images/")))
			isImage = true
		default:
			continue // 第一遍已拒绝其余条目，此处兜底跳过
		}
		if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
			return stats, fmt.Errorf("create directory for %s: %w", name, err)
		}
		n, err := extractZipEntry(entry, dest)
		if err != nil {
			return stats, err
		}
		writtenTotal += n
		if writtenTotal > importMaxTotalBytes {
			return stats, importFail("IMPORT_BAD_ZIP", "total uncompressed size exceeds 1GB limit")
		}
		if isImage {
			stats.Count++
			stats.Bytes += n
		}
	}
	return stats, nil
}

// extractZipEntry 解压单个条目到 dest（先写临时文件再 rename，同名覆盖），
// 返回实际写出字节数；单文件限额用 io.LimitReader 硬截断复检。
func extractZipEntry(entry *zip.File, dest string) (int64, error) {
	rc, err := entry.Open()
	if err != nil {
		return 0, importFail("IMPORT_BAD_ZIP", fmt.Sprintf("cannot read zip entry %s", entry.Name))
	}
	defer rc.Close()
	tmp, err := os.CreateTemp(filepath.Dir(dest), ".import-*")
	if err != nil {
		return 0, fmt.Errorf("create temp file for %s: %w", entry.Name, err)
	}
	tmpName := tmp.Name()
	n, copyErr := io.Copy(tmp, io.LimitReader(rc, importMaxFileBytes+1))
	closeErr := tmp.Close()
	if copyErr != nil || closeErr != nil {
		_ = os.Remove(tmpName)
		return 0, importFail("IMPORT_BAD_ZIP",
			fmt.Sprintf("corrupted zip entry %s: %v", entry.Name, copyErr))
	}
	if n > importMaxFileBytes {
		_ = os.Remove(tmpName)
		return 0, importFail("IMPORT_BAD_ZIP",
			fmt.Sprintf("zip entry %s exceeds 200MB limit", entry.Name))
	}
	if err := os.Rename(tmpName, dest); err != nil {
		_ = os.Remove(tmpName)
		return 0, fmt.Errorf("move %s into place: %w", entry.Name, err)
	}
	return n, nil
}

// mergeImportCourses 读 seedDir/courses.json（不存在视为空列表），按 slug
// 原位替换/追加包内条目，返回合并后的完整列表（包内 slug 重复同样按原位
// 替换处理，后者覆盖前者）。
func mergeImportCourses(seedDir string, incoming []importCourse) ([]importCourse, error) {
	var current []importCourse
	raw, err := os.ReadFile(filepath.Join(seedDir, "courses.json"))
	switch {
	case errors.Is(err, os.ErrNotExist):
		// 磁盘无 courses.json：视为空列表，全部追加。
	case err != nil:
		return nil, fmt.Errorf("read existing courses.json: %w", err)
	default:
		var payload importCoursesFile
		if err := json.Unmarshal(raw, &payload); err != nil {
			return nil, fmt.Errorf("parse existing courses.json: %w", err)
		}
		current = payload.Courses
	}
	index := make(map[string]int, len(current))
	for i, course := range current {
		index[course.Slug] = i
	}
	for _, course := range incoming {
		if i, ok := index[course.Slug]; ok {
			current[i] = course
			continue
		}
		index[course.Slug] = len(current)
		current = append(current, course)
	}
	return current, nil
}

// writeCoursesJSONAtomic 把合并结果序列化（两空格缩进 + 末尾换行）并原子写回
// seedDir/courses.json（临时文件 + rename，避免半写状态）。
func writeCoursesJSONAtomic(seedDir string, courses []importCourse) error {
	raw, err := json.MarshalIndent(importCoursesFile{Courses: courses}, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal courses.json: %w", err)
	}
	raw = append(raw, '\n')
	tmp, err := os.CreateTemp(seedDir, "courses.json.*.tmp")
	if err != nil {
		return fmt.Errorf("create temp courses.json: %w", err)
	}
	tmpName := tmp.Name()
	if _, err := tmp.Write(raw); err != nil {
		_ = tmp.Close()
		_ = os.Remove(tmpName)
		return fmt.Errorf("write temp courses.json: %w", err)
	}
	if err := tmp.Close(); err != nil {
		_ = os.Remove(tmpName)
		return fmt.Errorf("close temp courses.json: %w", err)
	}
	if err := os.Rename(tmpName, filepath.Join(seedDir, "courses.json")); err != nil {
		_ = os.Remove(tmpName)
		return fmt.Errorf("rename courses.json: %w", err)
	}
	return nil
}
