package api_test

// 管理端课程包导入接口测试：happy path（落盘 + 合并 courses.json + 立即
// upsert 无需重启）、路径穿越、章节 md 缺失、courses.json 非法 JSON、
// 伪造超大 UncompressedSize64 头的解压超限。

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"

	"code-tutorials/backend/internal/api"
	"code-tutorials/backend/internal/store"
)

// pkgChapter / pkgCourse 课程包 courses.json 条目（与磁盘种子 schema 一致）。
type pkgChapter struct {
	Slug      string `json:"slug"`
	Title     string `json:"title"`
	SortOrder int    `json:"sort_order"`
	File      string `json:"file"`
}

type pkgCourse struct {
	Slug      string       `json:"slug"`
	Title     string       `json:"title"`
	Summary   string       `json:"summary"`
	Language  string       `json:"language"`
	Color     string       `json:"color"`
	SortOrder int          `json:"sort_order"`
	Chapters  []pkgChapter `json:"chapters"`
}

// marshalCourses 序列化 {"courses":[...]}。
func marshalCourses(t *testing.T, courses []pkgCourse) []byte {
	t.Helper()
	raw, err := json.Marshal(struct {
		Courses []pkgCourse `json:"courses"`
	}{Courses: courses})
	if err != nil {
		t.Fatalf("marshal courses: %v", err)
	}
	return raw
}

// zipEntry 内存 zip 的单个条目。
type zipEntry struct {
	name string
	body []byte
}

// buildZip 在内存构造课程包 zip。
func buildZip(t *testing.T, entries []zipEntry) []byte {
	t.Helper()
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	for _, e := range entries {
		w, err := zw.Create(e.name)
		if err != nil {
			t.Fatalf("create zip entry %s: %v", e.name, err)
		}
		if _, err := w.Write(e.body); err != nil {
			t.Fatalf("write zip entry %s: %v", e.name, err)
		}
	}
	if err := zw.Close(); err != nil {
		t.Fatalf("close zip: %v", err)
	}
	return buf.Bytes()
}

// buildOversizeZip 构造声明超大 UncompressedSize64 的 zip：big.md 头声明
// 0x7FFFFFFF（2GB-1 > 200MB 单文件限额），实际只写少量字节，用于验证按
// entry 头预检超限（读取前即中止）。
func buildOversizeZip(t *testing.T) []byte {
	t.Helper()
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	jw, err := zw.Create("courses.json")
	if err != nil {
		t.Fatalf("create courses.json entry: %v", err)
	}
	if _, err := jw.Write([]byte(`{"courses":[]}`)); err != nil {
		t.Fatalf("write courses.json entry: %v", err)
	}
	fh := &zip.FileHeader{Name: "big.md", Method: zip.Deflate}
	fh.SetMode(0o644)
	fh.UncompressedSize64 = 0x7FFFFFFF
	fh.CompressedSize64 = 9
	rw, err := zw.CreateRaw(fh)
	if err != nil {
		t.Fatalf("create raw big.md entry: %v", err)
	}
	if _, err := rw.Write([]byte("small!!!")); err != nil {
		t.Fatalf("write raw big.md entry: %v", err)
	}
	if err := zw.Close(); err != nil {
		t.Fatalf("close zip: %v", err)
	}
	return buf.Bytes()
}

// newImportRouter 打开独立临时数据库并注入临时 seedDir/imagesRoot；
// preseed=true 时 seedDir 预置一门 legacy-course（courses.json + legacy.md），
// 启动播种进 DB，用于验证合并语义与 updated 状态。
func newImportRouter(t *testing.T, preseed bool) (*gin.Engine, string, string) {
	t.Helper()
	t.Setenv("ADMIN_TOKEN", "dev123")
	seedDir := t.TempDir()
	imgRoot := t.TempDir()
	if preseed {
		legacy := []pkgCourse{{
			Slug: "legacy-course", Title: "Legacy 课程", Summary: "磁盘预置旧课",
			Language: "X", Color: "#4C6BB0", SortOrder: 1,
			Chapters: []pkgChapter{{Slug: "legacy-ch", Title: "旧章", SortOrder: 1, File: "legacy.md"}},
		}}
		if err := os.WriteFile(filepath.Join(seedDir, "courses.json"), marshalCourses(t, legacy), 0o644); err != nil {
			t.Fatalf("preseed courses.json: %v", err)
		}
		if err := os.WriteFile(filepath.Join(seedDir, "legacy.md"), []byte("## old\n\nold content\n"), 0o644); err != nil {
			t.Fatalf("preseed legacy.md: %v", err)
		}
	}
	db, err := store.OpenSeed(filepath.Join(t.TempDir(), "test.db"), seedDir)
	if err != nil {
		t.Fatalf("open test store: %v", err)
	}
	t.Cleanup(func() {
		if sqlDB, err := db.DB(); err == nil {
			_ = sqlDB.Close()
		}
	})
	return api.NewRouterWithDirs(db, seedDir, imgRoot), seedDir, imgRoot
}

// postImportZip 以 multipart 字段 file 上传课程包 zip 并返回响应。
func postImportZip(t *testing.T, r *gin.Engine, token string, zipBytes []byte) (int, response) {
	t.Helper()
	var body bytes.Buffer
	mw := multipart.NewWriter(&body)
	fw, err := mw.CreateFormFile("file", "courses.zip")
	if err != nil {
		t.Fatalf("create form file: %v", err)
	}
	if _, err := fw.Write(zipBytes); err != nil {
		t.Fatalf("write form file: %v", err)
	}
	if err := mw.Close(); err != nil {
		t.Fatalf("close multipart writer: %v", err)
	}
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/admin/courses/import", &body)
	req.Header.Set("Content-Type", mw.FormDataContentType())
	if token != "" {
		req.Header.Set("X-Admin-Token", token)
	}
	r.ServeHTTP(w, req)
	var resp response
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response body %q: %v", w.Body.String(), err)
	}
	return w.Code, resp
}

// wantImportFailure 断言导入失败的状态码/错误码/消息片段。
func wantImportFailure(t *testing.T, status int, resp response, code, messagePart string) {
	t.Helper()
	if status != http.StatusBadRequest || resp.Code != code {
		t.Fatalf("status = %d code = %s, want 400 %s (message: %s)", status, resp.Code, code, resp.Message)
	}
	if !strings.Contains(resp.Message, messagePart) {
		t.Fatalf("message = %q, want it to contain %q", resp.Message, messagePart)
	}
}

// importResultData 200 响应的 data 结构。
type importResultData struct {
	Courses []struct {
		Slug     string `json:"slug"`
		Title    string `json:"title"`
		Chapters int    `json:"chapters"`
		State    string `json:"state"`
	} `json:"courses"`
	Images struct {
		Count int   `json:"count"`
		Bytes int64 `json:"bytes"`
	} `json:"images"`
}

func TestCourseImportHappyPath(t *testing.T) {
	r, seedDir, imgRoot := newImportRouter(t, true)

	jc1Body := []byte("## jc one\n\nJetpack 第一章正文。\n\n- 要点一\n- 要点二\n")
	jc2Body := []byte("## jc two\n\nJetpack 第二章正文。\n")
	legacyNew := []byte("## new legacy\n\n导入覆盖后的正文。\n")
	pngBody := []byte("fake-png-bytes-for-import")
	pkg := []pkgCourse{
		{
			Slug: "jetpack-compose", Title: "Jetpack Compose 入门", Summary: "新导入课程",
			Language: "Kotlin", Color: "#4285F4", SortOrder: 5,
			Chapters: []pkgChapter{
				{Slug: "jc-one", Title: "第一章", SortOrder: 1, File: "jc-1.md"},
				{Slug: "jc-two", Title: "第二章", SortOrder: 2, File: "jc-2.md"},
			},
		},
		{
			Slug: "legacy-course", Title: "Legacy 课程（更新）", Summary: "原位替换旧课",
			Language: "X", Color: "#4C6BB0", SortOrder: 1,
			Chapters: []pkgChapter{{Slug: "legacy-ch", Title: "旧章（更新）", SortOrder: 1, File: "legacy.md"}},
		},
	}
	zipBytes := buildZip(t, []zipEntry{
		{name: "courses.json", body: marshalCourses(t, pkg)},
		{name: "jc-1.md", body: jc1Body},
		{name: "jc-2.md", body: jc2Body},
		{name: "legacy.md", body: legacyNew},
		{name: "images/a/b.png", body: pngBody},
	})

	// 管理端鉴权照旧：缺 token 403。
	if status, resp := postImportZip(t, r, "", zipBytes); status != http.StatusForbidden || resp.Code != "FORBIDDEN" {
		t.Fatalf("import without token: status = %d code = %s, want 403 FORBIDDEN", status, resp.Code)
	}

	status, resp := postImportZip(t, r, "dev123", zipBytes)
	if status != http.StatusOK || resp.Code != "OK" {
		t.Fatalf("import: status = %d code = %s (message: %s), want 200 OK", status, resp.Code, resp.Message)
	}
	var data importResultData
	if err := json.Unmarshal(resp.Data, &data); err != nil {
		t.Fatalf("unmarshal import data %s: %v", resp.Data, err)
	}
	if len(data.Courses) != 2 {
		t.Fatalf("courses in result = %d, want 2 (data: %s)", len(data.Courses), resp.Data)
	}
	jc, legacy := data.Courses[0], data.Courses[1]
	if jc.Slug != "jetpack-compose" || jc.Title != "Jetpack Compose 入门" || jc.Chapters != 2 || jc.State != "created" {
		t.Fatalf("jetpack-compose result = %+v, want created with 2 chapters", jc)
	}
	if legacy.Slug != "legacy-course" || legacy.Chapters != 1 || legacy.State != "updated" {
		t.Fatalf("legacy-course result = %+v, want updated with 1 chapter", legacy)
	}
	if data.Images.Count != 1 || data.Images.Bytes != int64(len(pngBody)) {
		t.Fatalf("images stats = %+v, want count 1 bytes %d", data.Images, len(pngBody))
	}

	// 立即 upsert 进 DB，无需重启：新课章节可读且正文正确。
	detail := mustOK(t, r, "/api/v1/courses/jetpack-compose")
	var detailData struct {
		Chapters []struct {
			Slug  string `json:"slug"`
			Order int    `json:"order"`
		} `json:"chapters"`
	}
	if err := json.Unmarshal(detail.Data, &detailData); err != nil {
		t.Fatalf("unmarshal course detail: %v", err)
	}
	if len(detailData.Chapters) != 2 || detailData.Chapters[0].Slug != "jc-one" || detailData.Chapters[1].Slug != "jc-two" {
		t.Fatalf("jetpack-compose chapters = %+v", detailData.Chapters)
	}
	chapter := mustOK(t, r, "/api/v1/courses/jetpack-compose/chapters/jc-one")
	var chapterData struct {
		ContentMD string `json:"content_md"`
	}
	if err := json.Unmarshal(chapter.Data, &chapterData); err != nil {
		t.Fatalf("unmarshal chapter: %v", err)
	}
	if chapterData.ContentMD != string(jc1Body) {
		t.Fatalf("jc-one content_md = %q, want zip 里 jc-1.md 全文", chapterData.ContentMD)
	}
	// 旧课被原位替换：章节正文更新为新 legacy.md。
	updated := mustOK(t, r, "/api/v1/courses/legacy-course/chapters/legacy-ch")
	var updatedData struct {
		ContentMD string `json:"content_md"`
	}
	if err := json.Unmarshal(updated.Data, &updatedData); err != nil {
		t.Fatalf("unmarshal legacy chapter: %v", err)
	}
	if updatedData.ContentMD != string(legacyNew) {
		t.Fatalf("legacy-ch content_md = %q, want updated content", updatedData.ContentMD)
	}

	// 磁盘就位：md、图片、合并后的 courses.json（旧课仍在，新课追加在后）。
	for name, want := range map[string][]byte{
		filepath.Join(seedDir, "jc-1.md"):    jc1Body,
		filepath.Join(seedDir, "jc-2.md"):    jc2Body,
		filepath.Join(seedDir, "legacy.md"):  legacyNew,
		filepath.Join(imgRoot, "a", "b.png"): pngBody,
	} {
		got, err := os.ReadFile(name)
		if err != nil {
			t.Fatalf("read extracted %s: %v", name, err)
		}
		if string(got) != string(want) {
			t.Fatalf("extracted %s = %q, want %q", name, got, want)
		}
	}
	mergedRaw, err := os.ReadFile(filepath.Join(seedDir, "courses.json"))
	if err != nil {
		t.Fatalf("read merged courses.json: %v", err)
	}
	var merged struct {
		Courses []struct {
			Slug string `json:"slug"`
		} `json:"courses"`
	}
	if err := json.Unmarshal(mergedRaw, &merged); err != nil {
		t.Fatalf("parse merged courses.json: %v", err)
	}
	if len(merged.Courses) != 2 || merged.Courses[0].Slug != "legacy-course" || merged.Courses[1].Slug != "jetpack-compose" {
		t.Fatalf("merged courses = %+v, want legacy-course in place then jetpack-compose appended", merged.Courses)
	}
	if !strings.HasSuffix(string(mergedRaw), "\n") || !strings.Contains(string(mergedRaw), "\n  \"courses\"") {
		t.Fatalf("merged courses.json not normalized to 2-space indent with trailing newline: %q", string(mergedRaw))
	}

	// 图片经 /images 静态路由可取回（imagesRoot 注入生效）。
	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/images/a/b.png", nil))
	if w.Code != http.StatusOK || !bytes.Equal(w.Body.Bytes(), pngBody) {
		t.Fatalf("GET /images/a/b.png: status = %d body = %q, want 200 with extracted bytes", w.Code, w.Body.String())
	}
}

func TestCourseImportPathTraversal(t *testing.T) {
	r, seedDir, _ := newImportRouter(t, false)

	pkg := []pkgCourse{{
		Slug: "evil-course", Title: "Evil", Summary: "", Language: "X", Color: "#14B8A6", SortOrder: 1,
		Chapters: []pkgChapter{{Slug: "evil", Title: "E", SortOrder: 1, File: "evil.md"}},
	}}
	zipBytes := buildZip(t, []zipEntry{
		{name: "courses.json", body: marshalCourses(t, pkg)},
		{name: "../evil.md", body: []byte("escaped")},
	})
	status, resp := postImportZip(t, r, "dev123", zipBytes)
	wantImportFailure(t, status, resp, "IMPORT_BAD_ZIP", "../evil.md")

	// 未越出 seedDir 写文件。
	if _, err := os.Stat(filepath.Join(filepath.Dir(seedDir), "evil.md")); err == nil {
		t.Fatal("evil.md escaped outside seedDir")
	}
}

func TestCourseImportMissingChapterFiles(t *testing.T) {
	r, _, _ := newImportRouter(t, false)

	pkg := []pkgCourse{{
		Slug: "partial-course", Title: "Partial", Summary: "", Language: "X", Color: "#14B8A6", SortOrder: 1,
		Chapters: []pkgChapter{
			{Slug: "ok", Title: "OK", SortOrder: 1, File: "ok.md"},
			{Slug: "miss-a", Title: "A", SortOrder: 2, File: "missing-a.md"},
			{Slug: "miss-b", Title: "B", SortOrder: 3, File: "missing-b.md"},
		},
	}}
	zipBytes := buildZip(t, []zipEntry{
		{name: "courses.json", body: marshalCourses(t, pkg)},
		{name: "ok.md", body: []byte("## ok\n")},
	})
	status, resp := postImportZip(t, r, "dev123", zipBytes)
	wantImportFailure(t, status, resp, "IMPORT_MISSING_FILES", "missing-a.md")
	if !strings.Contains(resp.Message, "missing-b.md") {
		t.Fatalf("message = %q, want both missing file names listed", resp.Message)
	}

	// 失败不落盘：课程未入库、md 未写。
	if status, resp := doGet(t, r, "/api/v1/courses/partial-course"); status != http.StatusNotFound || resp.Code != "NOT_FOUND" {
		t.Fatalf("course after failed import: status = %d, want 404", status)
	}
}

func TestCourseImportInvalidCoursesJSON(t *testing.T) {
	r, _, _ := newImportRouter(t, false)

	zipBytes := buildZip(t, []zipEntry{
		{name: "courses.json", body: []byte("{not json")},
		{name: "ok.md", body: []byte("## ok\n")},
	})
	status, resp := postImportZip(t, r, "dev123", zipBytes)
	wantImportFailure(t, status, resp, "IMPORT_INVALID_PACKAGE", "courses.json")
}

func TestCourseImportOversizedEntry(t *testing.T) {
	r, _, _ := newImportRouter(t, false)

	status, resp := postImportZip(t, r, "dev123", buildOversizeZip(t))
	wantImportFailure(t, status, resp, "IMPORT_BAD_ZIP", "big.md")
}
