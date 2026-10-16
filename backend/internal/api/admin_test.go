package api_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"

	"code-tutorials/backend/web"
)

// adminDo 发起管理端请求；token 非空时带上 X-Admin-Token 请求头。
func adminDo(t *testing.T, r *gin.Engine, method, path, token string, body interface{}) (int, response) {
	t.Helper()
	var reader *bytes.Reader
	if body != nil {
		raw, err := json.Marshal(body)
		if err != nil {
			t.Fatalf("marshal request body: %v", err)
		}
		reader = bytes.NewReader(raw)
	} else {
		reader = bytes.NewReader(nil)
	}
	w := httptest.NewRecorder()
	req := httptest.NewRequest(method, path, reader)
	req.Header.Set("Content-Type", "application/json")
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

// wantForbidden 断言 403 FORBIDDEN 及错误信息。
func wantForbidden(t *testing.T, status int, resp response, message string) {
	t.Helper()
	if status != http.StatusForbidden {
		t.Fatalf("status = %d, want 403 (body code: %s)", status, resp.Code)
	}
	if resp.Code != "FORBIDDEN" {
		t.Fatalf("code = %q, want FORBIDDEN", resp.Code)
	}
	if resp.Message != message {
		t.Fatalf("message = %q, want %q", resp.Message, message)
	}
	if string(resp.Data) != "null" {
		t.Fatalf("data = %s, want null", resp.Data)
	}
}

// newCourseBody 构造合法的课程请求体。
func newCourseBody(slug string) map[string]interface{} {
	return map[string]interface{}{
		"slug":     slug,
		"title":    "Rust 入门",
		"summary":  "Rust 课程摘要",
		"language": "Rust",
	}
}

func TestAdminAuth(t *testing.T) {
	r := newRouter(t)

	// ADMIN_TOKEN 未设置（空串等价未设置）：一律 403 admin disabled。
	t.Setenv("ADMIN_TOKEN", "")
	status, resp := adminDo(t, r, http.MethodPost, "/api/v1/admin/courses", "", newCourseBody("rust-basics"))
	wantForbidden(t, status, resp, "admin disabled: ADMIN_TOKEN not set")

	// ADMIN_TOKEN 已设置：缺头、错 token 都 403。
	t.Setenv("ADMIN_TOKEN", "dev123")
	status, resp = adminDo(t, r, http.MethodPost, "/api/v1/admin/courses", "", newCourseBody("rust-basics"))
	wantForbidden(t, status, resp, "invalid admin token")
	status, resp = adminDo(t, r, http.MethodPost, "/api/v1/admin/courses", "wrong-token", newCourseBody("rust-basics"))
	wantForbidden(t, status, resp, "invalid admin token")

	// 正确 token 放行。
	status, resp = adminDo(t, r, http.MethodPost, "/api/v1/admin/courses", "dev123", newCourseBody("rust-basics"))
	if status != http.StatusOK || resp.Code != "OK" {
		t.Fatalf("valid token: status = %d code = %s, want 200 OK", status, resp.Code)
	}
}

func TestAdminCourseCRUD(t *testing.T) {
	t.Setenv("ADMIN_TOKEN", "dev123")
	r := newRouter(t)

	// 创建：color 缺省、sort_order 缺省排最后。
	status, resp := adminDo(t, r, http.MethodPost, "/api/v1/admin/courses", "dev123", map[string]interface{}{
		"slug":     "rust-basics",
		"title":    "Rust 入门",
		"summary":  "Rust 课程摘要",
		"language": "Rust",
	})
	if status != http.StatusOK || resp.Code != "OK" {
		t.Fatalf("create: status = %d code = %s, want 200 OK", status, resp.Code)
	}
	var course struct {
		Slug      string `json:"slug"`
		Title     string `json:"title"`
		Summary   string `json:"summary"`
		Language  string `json:"language"`
		Color     string `json:"color"`
		UpdatedAt string `json:"updated_at"`
		Chapters  []struct {
			Slug string `json:"slug"`
		} `json:"chapters"`
	}
	if err := json.Unmarshal(resp.Data, &course); err != nil {
		t.Fatalf("unmarshal course data: %v", err)
	}
	if course.Slug != "rust-basics" || course.Title != "Rust 入门" || course.Language != "Rust" {
		t.Fatalf("created course = %+v", course)
	}
	if course.Color != "#14B8A6" {
		t.Fatalf("default color = %q, want #14B8A6", course.Color)
	}
	if len(course.Chapters) != 0 {
		t.Fatalf("new course chapters = %v, want empty", course.Chapters)
	}
	assertRFC3339(t, "POST /api/v1/admin/courses", "updated_at", course.UpdatedAt)

	// 只读接口可见：详情 200、列表排最后、chapter_count = 0。
	detail := mustOK(t, r, "/api/v1/courses/rust-basics")
	var detailData struct {
		Slug string `json:"slug"`
	}
	if err := json.Unmarshal(detail.Data, &detailData); err != nil || detailData.Slug != "rust-basics" {
		t.Fatalf("GET detail after create: slug = %q err = %v", detailData.Slug, err)
	}
	list := mustOK(t, r, "/api/v1/courses")
	var items []struct {
		Slug         string `json:"slug"`
		ChapterCount int    `json:"chapter_count"`
	}
	if err := json.Unmarshal(list.Data, &items); err != nil {
		t.Fatalf("unmarshal courses list: %v", err)
	}
	if len(items) != 3 || items[2].Slug != "rust-basics" || items[2].ChapterCount != 0 {
		t.Fatalf("list after create = %+v, want rust-basics last with 0 chapters", items)
	}

	// 更新：改 title/color/sort_order（body 不带 slug，slug 以 path 为准）。
	status, resp = adminDo(t, r, http.MethodPut, "/api/v1/admin/courses/rust-basics", "dev123", map[string]interface{}{
		"title":      "Rust 进阶",
		"summary":    "新摘要",
		"language":   "Rust",
		"color":      "#3B82F6",
		"sort_order": 0,
	})
	if status != http.StatusOK || resp.Code != "OK" {
		t.Fatalf("update: status = %d code = %s, want 200 OK", status, resp.Code)
	}
	updated := mustOK(t, r, "/api/v1/courses/rust-basics")
	var updatedData struct {
		Title string `json:"title"`
		Color string `json:"color"`
	}
	if err := json.Unmarshal(updated.Data, &updatedData); err != nil {
		t.Fatalf("unmarshal updated course: %v", err)
	}
	if updatedData.Title != "Rust 进阶" || updatedData.Color != "#3B82F6" {
		t.Fatalf("updated course = %+v", updatedData)
	}
	first := mustOK(t, r, "/api/v1/courses")
	var reordered []struct {
		Slug string `json:"slug"`
	}
	if err := json.Unmarshal(first.Data, &reordered); err != nil {
		t.Fatalf("unmarshal reordered list: %v", err)
	}
	if reordered[0].Slug != "rust-basics" {
		t.Fatalf("reordered[0] = %q, want rust-basics first", reordered[0].Slug)
	}

	// 更新不存在的课程 → 404。
	status, resp = adminDo(t, r, http.MethodPut, "/api/v1/admin/courses/no-such", "dev123", newCourseBody("no-such"))
	if status != http.StatusNotFound || resp.Code != "NOT_FOUND" {
		t.Fatalf("update missing: status = %d code = %s, want 404 NOT_FOUND", status, resp.Code)
	}

	// 删除 → deleted:true；详情 404；再删 → 404。
	status, resp = adminDo(t, r, http.MethodDelete, "/api/v1/admin/courses/rust-basics", "dev123", nil)
	if status != http.StatusOK || resp.Code != "OK" || string(resp.Data) != `{"deleted":true}` {
		t.Fatalf("delete: status = %d code = %s data = %s, want 200 OK {\"deleted\":true}", status, resp.Code, resp.Data)
	}
	status, resp = doGet(t, r, "/api/v1/courses/rust-basics")
	if status != http.StatusNotFound {
		t.Fatalf("GET after delete: status = %d, want 404", status)
	}
	status, resp = adminDo(t, r, http.MethodDelete, "/api/v1/admin/courses/rust-basics", "dev123", nil)
	if status != http.StatusNotFound || resp.Code != "NOT_FOUND" {
		t.Fatalf("delete missing: status = %d code = %s, want 404 NOT_FOUND", status, resp.Code)
	}
}

// TestAdminCourseDeleteCascades 验证删除课程连同其章节一起删除。
func TestAdminCourseDeleteCascades(t *testing.T) {
	t.Setenv("ADMIN_TOKEN", "dev123")
	r := newRouter(t)

	if status, resp := adminDo(t, r, http.MethodDelete, "/api/v1/admin/courses/go-basics", "dev123", nil); status != http.StatusOK {
		t.Fatalf("delete go-basics: status = %d code = %s", status, resp.Code)
	}
	for _, path := range []string{
		"/api/v1/courses/go-basics",
		"/api/v1/courses/go-basics/chapters/hello-world",
	} {
		if status, resp := doGet(t, r, path); status != http.StatusNotFound {
			t.Fatalf("%s after course delete: status = %d code = %s, want 404", path, status, resp.Code)
		}
	}
}

func TestAdminCourseValidation(t *testing.T) {
	t.Setenv("ADMIN_TOKEN", "dev123")
	r := newRouter(t)

	cases := []struct {
		name    string
		body    map[string]interface{}
		message string
	}{
		{"missing slug", map[string]interface{}{"title": "T"}, "slug is required"},
		{"missing title", map[string]interface{}{"slug": "x-slug"}, "title is required"},
		{"bad color", map[string]interface{}{"slug": "x-slug", "title": "T", "color": "red"}, "invalid color: want #RRGGBB"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			status, resp := adminDo(t, r, http.MethodPost, "/api/v1/admin/courses", "dev123", tc.body)
			if status != http.StatusBadRequest || resp.Code != "BAD_REQUEST" || resp.Message != tc.message {
				t.Fatalf("status = %d code = %s message = %q, want 400 BAD_REQUEST %q",
					status, resp.Code, resp.Message, tc.message)
			}
		})
	}

	// 重复 slug → 400。
	if status, resp := adminDo(t, r, http.MethodPost, "/api/v1/admin/courses", "dev123", newCourseBody("go-basics")); status != http.StatusBadRequest {
		t.Fatalf("duplicate slug: status = %d code = %s, want 400", status, resp.Code)
	}

	// 非法 JSON → 400。
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/admin/courses", bytes.NewReader([]byte("{not json")))
	req.Header.Set("X-Admin-Token", "dev123")
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("invalid json: status = %d, want 400", w.Code)
	}
}

func TestAdminChapterCRUD(t *testing.T) {
	t.Setenv("ADMIN_TOKEN", "dev123")
	r := newRouter(t)

	// 创建：sort_order 缺省排最后（go-basics 现有 3 章 → order = 4）。
	status, resp := adminDo(t, r, http.MethodPost, "/api/v1/admin/courses/go-basics/chapters", "dev123", map[string]interface{}{
		"slug":       "extra",
		"title":      "额外章节",
		"content_md": "## 额外章节\n\n管理端添加的内容。\n",
	})
	if status != http.StatusOK || resp.Code != "OK" {
		t.Fatalf("create chapter: status = %d code = %s, want 200 OK", status, resp.Code)
	}
	var chapter struct {
		Slug       string `json:"slug"`
		CourseSlug string `json:"course_slug"`
		Title      string `json:"title"`
		Order      int    `json:"order"`
		UpdatedAt  string `json:"updated_at"`
	}
	if err := json.Unmarshal(resp.Data, &chapter); err != nil {
		t.Fatalf("unmarshal chapter data: %v", err)
	}
	if chapter.Slug != "extra" || chapter.CourseSlug != "go-basics" || chapter.Title != "额外章节" || chapter.Order != 4 {
		t.Fatalf("created chapter = %+v", chapter)
	}
	assertRFC3339(t, "POST admin chapters", "updated_at", chapter.UpdatedAt)

	// 只读接口可见，正文一致。
	got := mustOK(t, r, "/api/v1/courses/go-basics/chapters/extra")
	var gotData struct {
		ContentMD string `json:"content_md"`
	}
	if err := json.Unmarshal(got.Data, &gotData); err != nil || gotData.ContentMD != "## 额外章节\n\n管理端添加的内容。\n" {
		t.Fatalf("GET chapter content = %q err = %v", gotData.ContentMD, err)
	}

	// 同课程下重复 slug → 400。
	status, resp = adminDo(t, r, http.MethodPost, "/api/v1/admin/courses/go-basics/chapters", "dev123", map[string]interface{}{
		"slug": "extra", "title": "重复",
	})
	if status != http.StatusBadRequest || resp.Code != "BAD_REQUEST" || resp.Message != "chapter slug already exists" {
		t.Fatalf("duplicate chapter: status = %d code = %s message = %q", status, resp.Code, resp.Message)
	}

	// 课程不存在 → 404。
	status, resp = adminDo(t, r, http.MethodPost, "/api/v1/admin/courses/no-such/chapters", "dev123", map[string]interface{}{
		"slug": "some-chapter", "title": "T",
	})
	if status != http.StatusNotFound || resp.Code != "NOT_FOUND" {
		t.Fatalf("chapter on missing course: status = %d code = %s, want 404", status, resp.Code)
	}

	// 更新：改 title/content_md。
	status, resp = adminDo(t, r, http.MethodPut, "/api/v1/admin/courses/go-basics/chapters/extra", "dev123", map[string]interface{}{
		"slug":       "ignored-slug",
		"title":      "改名后的章节",
		"content_md": "## 改后\n\n新内容。\n",
	})
	if status != http.StatusOK || resp.Code != "OK" {
		t.Fatalf("update chapter: status = %d code = %s, want 200 OK", status, resp.Code)
	}
	got = mustOK(t, r, "/api/v1/courses/go-basics/chapters/extra")
	if err := json.Unmarshal(got.Data, &gotData); err != nil || gotData.ContentMD != "## 改后\n\n新内容。\n" {
		t.Fatalf("chapter content after update = %q err = %v", gotData.ContentMD, err)
	}
	// 章节目录同步更新。
	detail := mustOK(t, r, "/api/v1/courses/go-basics")
	var detailData struct {
		Chapters []struct {
			Slug  string `json:"slug"`
			Title string `json:"title"`
			Order int    `json:"order"`
		} `json:"chapters"`
	}
	if err := json.Unmarshal(detail.Data, &detailData); err != nil {
		t.Fatalf("unmarshal course detail: %v", err)
	}
	if len(detailData.Chapters) != 4 || detailData.Chapters[3].Title != "改名后的章节" {
		t.Fatalf("chapters after update = %+v", detailData.Chapters)
	}

	// 更新：课程不存在 / 章节不存在 → 404。
	for _, path := range []string{
		"/api/v1/admin/courses/no-such/chapters/extra",
		"/api/v1/admin/courses/go-basics/chapters/no-such",
	} {
		status, resp = adminDo(t, r, http.MethodPut, path, "dev123", map[string]interface{}{"title": "T"})
		if status != http.StatusNotFound || resp.Code != "NOT_FOUND" {
			t.Fatalf("PUT %s: status = %d code = %s, want 404 NOT_FOUND", path, status, resp.Code)
		}
	}

	// 删除 → deleted:true；详情 404；再删 404。
	status, resp = adminDo(t, r, http.MethodDelete, "/api/v1/admin/courses/go-basics/chapters/extra", "dev123", nil)
	if status != http.StatusOK || resp.Code != "OK" || string(resp.Data) != `{"deleted":true}` {
		t.Fatalf("delete chapter: status = %d code = %s data = %s", status, resp.Code, resp.Data)
	}
	if status, _ := doGet(t, r, "/api/v1/courses/go-basics/chapters/extra"); status != http.StatusNotFound {
		t.Fatalf("GET chapter after delete: status = %d, want 404", status)
	}
	status, resp = adminDo(t, r, http.MethodDelete, "/api/v1/admin/courses/go-basics/chapters/extra", "dev123", nil)
	if status != http.StatusNotFound || resp.Code != "NOT_FOUND" {
		t.Fatalf("delete missing chapter: status = %d code = %s, want 404 NOT_FOUND", status, resp.Code)
	}
}

// TestAdminStaticSPA 验证后台静态托管（编译期 go:embed 嵌入 web.DistFS）与
// SPA 回退：占位 index.html 在编译期进二进制，可直接断言其内容。
func TestAdminStaticSPA(t *testing.T) {
	t.Setenv("ADMIN_TOKEN", "dev123")
	r := newRouter(t)

	// 嵌入的占位 index.html：/admin/ 可直接 GET（SPA 入口，hash 路由也由
	// 它承载），未知子路径回退到同一页面。
	index, err := web.DistFS.ReadFile("dist/index.html")
	if err != nil {
		t.Fatalf("read embedded index.html: %v", err)
	}
	if !strings.Contains(string(index), "admin frontend placeholder") {
		t.Fatalf("embedded index.html missing placeholder text: %q", string(index))
	}
	for _, path := range []string{"/admin/", "/admin/courses/new", "/admin/a/b/c"} {
		w := httptest.NewRecorder()
		r.ServeHTTP(w, httptest.NewRequest(http.MethodGet, path, nil))
		if w.Code != http.StatusOK || w.Body.String() != string(index) {
			t.Fatalf("GET %s: status = %d body = %q, want 200 embedded index.html", path, w.Code, w.Body.String())
		}
	}
	// 裸 /admin 由 Gin 尾斜杠重定向到 /admin/。
	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/admin", nil))
	if w.Code != http.StatusMovedPermanently {
		t.Fatalf("GET /admin: status = %d, want 301 redirect to /admin/", w.Code)
	}

	// 非 /admin 前缀的未知路径仍是 404 JSON 信封。
	if status, resp := doGet(t, r, "/api/v1/no-such-route"); status != http.StatusNotFound || resp.Code != "NOT_FOUND" {
		t.Fatalf("GET unknown api path: status = %d code = %s, want 404 NOT_FOUND", status, resp.Code)
	}
	if status, resp := doGet(t, r, "/administrator/panel"); status != http.StatusNotFound || resp.Code != "NOT_FOUND" {
		t.Fatalf("GET /administrator/panel: status = %d code = %s, want 404 NOT_FOUND", status, resp.Code)
	}
}
