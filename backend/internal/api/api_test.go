package api_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"

	"code-tutorials/backend/internal/api"
	"code-tutorials/backend/internal/store"
)

func TestMain(m *testing.M) {
	gin.SetMode(gin.TestMode)
	os.Exit(m.Run())
}

// newRouter 为每个用例打开独立的临时数据库，不污染 backend/data。
func newRouter(t *testing.T) *gin.Engine {
	t.Helper()
	db, err := store.Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatalf("open test store: %v", err)
	}
	t.Cleanup(func() {
		if sqlDB, err := db.DB(); err == nil {
			_ = sqlDB.Close()
		}
	})
	return api.NewRouter(db)
}

type response struct {
	Code    string          `json:"code"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data"`
}

func doGet(t *testing.T, r *gin.Engine, path string) (int, response) {
	t.Helper()
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, path, nil)
	r.ServeHTTP(w, req)
	var resp response
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response body %q: %v", w.Body.String(), err)
	}
	return w.Code, resp
}

func mustOK(t *testing.T, r *gin.Engine, path string) response {
	t.Helper()
	status, resp := doGet(t, r, path)
	if status != http.StatusOK {
		t.Fatalf("%s: status = %d, want 200 (body: %s)", path, status, resp.Data)
	}
	if resp.Code != "OK" || resp.Message != "ok" {
		t.Fatalf("%s: envelope code/message = %q/%q, want OK/ok", path, resp.Code, resp.Message)
	}
	return resp
}

func assertRFC3339(t *testing.T, path, field, value string) {
	t.Helper()
	if _, err := time.Parse(time.RFC3339, value); err != nil {
		t.Fatalf("%s: %s = %q is not RFC3339: %v", path, field, value, err)
	}
}

func TestMeta(t *testing.T) {
	r := newRouter(t)
	resp := mustOK(t, r, "/api/v1/meta")

	var data struct {
		ContentVersion string `json:"content_version"`
		CourseCount    int    `json:"course_count"`
	}
	if err := json.Unmarshal(resp.Data, &data); err != nil {
		t.Fatalf("unmarshal meta data: %v", err)
	}
	if data.ContentVersion == "" {
		t.Fatal("content_version is empty")
	}
	assertRFC3339(t, "/api/v1/meta", "content_version", data.ContentVersion)
	if data.CourseCount != 2 {
		t.Fatalf("course_count = %d, want 2", data.CourseCount)
	}
}

func TestCoursesSortedBySortOrder(t *testing.T) {
	r := newRouter(t)
	resp := mustOK(t, r, "/api/v1/courses")

	var items []struct {
		Slug         string `json:"slug"`
		Title        string `json:"title"`
		Summary      string `json:"summary"`
		Language     string `json:"language"`
		Color        string `json:"color"`
		ChapterCount int    `json:"chapter_count"`
		UpdatedAt    string `json:"updated_at"`
	}
	if err := json.Unmarshal(resp.Data, &items); err != nil {
		t.Fatalf("unmarshal courses data: %v", err)
	}
	if len(items) != 2 {
		t.Fatalf("course count = %d, want 2", len(items))
	}
	wantOrder := []string{"go-basics", "python-basics"}
	for i, slug := range wantOrder {
		if items[i].Slug != slug {
			t.Fatalf("items[%d].slug = %q, want %q", i, items[i].Slug, slug)
		}
		if items[i].Title == "" || items[i].Summary == "" || items[i].Language == "" || items[i].Color == "" {
			t.Fatalf("items[%d] has empty required fields: %+v", i, items[i])
		}
		assertRFC3339(t, "/api/v1/courses", "updated_at", items[i].UpdatedAt)
	}
	if items[0].ChapterCount != 3 {
		t.Fatalf("go-basics chapter_count = %d, want 3", items[0].ChapterCount)
	}
	if items[1].ChapterCount != 2 {
		t.Fatalf("python-basics chapter_count = %d, want 2", items[1].ChapterCount)
	}
	if items[0].Color != "#14B8A6" || items[1].Color != "#4C6BB0" {
		t.Fatalf("unexpected colors: %q, %q", items[0].Color, items[1].Color)
	}
}

func TestCourseDetailWithOrderedChapters(t *testing.T) {
	r := newRouter(t)
	resp := mustOK(t, r, "/api/v1/courses/go-basics")

	var data struct {
		Slug      string `json:"slug"`
		Title     string `json:"title"`
		Summary   string `json:"summary"`
		Language  string `json:"language"`
		Color     string `json:"color"`
		UpdatedAt string `json:"updated_at"`
		Chapters  []struct {
			Slug  string `json:"slug"`
			Title string `json:"title"`
			Order int    `json:"order"`
		} `json:"chapters"`
	}
	if err := json.Unmarshal(resp.Data, &data); err != nil {
		t.Fatalf("unmarshal course detail: %v", err)
	}
	if data.Slug != "go-basics" || data.Language != "Go" {
		t.Fatalf("unexpected course slug/language: %q/%q", data.Slug, data.Language)
	}
	assertRFC3339(t, "/api/v1/courses/go-basics", "updated_at", data.UpdatedAt)
	if len(data.Chapters) != 3 {
		t.Fatalf("chapters count = %d, want 3", len(data.Chapters))
	}
	want := []struct {
		slug  string
		title string
		order int
	}{
		{"hello-world", "Hello World", 1},
		{"variables", "变量与基本类型", 2},
		{"goroutine", "goroutine 并发入门", 3},
	}
	for i, w := range want {
		got := data.Chapters[i]
		if got.Slug != w.slug || got.Title != w.title || got.Order != w.order {
			t.Fatalf("chapters[%d] = {%q %q %d}, want {%q %q %d}",
				i, got.Slug, got.Title, got.Order, w.slug, w.title, w.order)
		}
	}
}

func TestChapterContentReturnsMarkdown(t *testing.T) {
	r := newRouter(t)

	cases := [][2]string{
		{"go-basics", "hello-world"},
		{"go-basics", "variables"},
		{"go-basics", "goroutine"},
		{"python-basics", "install-repl"},
		{"python-basics", "variables-controlflow"},
	}
	for _, tc := range cases {
		path := "/api/v1/courses/" + tc[0] + "/chapters/" + tc[1]
		resp := mustOK(t, r, path)

		var data struct {
			Slug       string `json:"slug"`
			CourseSlug string `json:"course_slug"`
			Title      string `json:"title"`
			ContentMD  string `json:"content_md"`
			UpdatedAt  string `json:"updated_at"`
		}
		if err := json.Unmarshal(resp.Data, &data); err != nil {
			t.Fatalf("%s: unmarshal chapter data: %v", path, err)
		}
		if data.Slug != tc[1] || data.CourseSlug != tc[0] {
			t.Fatalf("%s: slug/course_slug = %q/%q, want %q/%q", path, data.Slug, data.CourseSlug, tc[1], tc[0])
		}
		if data.Title == "" {
			t.Fatalf("%s: title is empty", path)
		}
		assertRFC3339(t, path, "updated_at", data.UpdatedAt)
		// 每章正文必须含代码块、二级标题、列表
		if !strings.Contains(data.ContentMD, "```") {
			t.Fatalf("%s: content_md has no fenced code block", path)
		}
		if !strings.HasPrefix(data.ContentMD, "## ") && !strings.Contains(data.ContentMD, "\n## ") {
			t.Fatalf("%s: content_md has no h2 heading", path)
		}
		if !strings.Contains(data.ContentMD, "\n- ") {
			t.Fatalf("%s: content_md has no list", path)
		}
		if len([]rune(data.ContentMD)) < 400 {
			t.Fatalf("%s: content_md too short (%d runes), want >= 400", path, len([]rune(data.ContentMD)))
		}
	}
}

func TestNotFoundEnvelope(t *testing.T) {
	r := newRouter(t)

	paths := []string{
		"/api/v1/courses/no-such-course",
		"/api/v1/courses/go-basics/chapters/no-such-chapter",
		"/api/v1/courses/no-such-course/chapters/hello-world",
		"/api/v1/no-such-route",
	}
	for _, path := range paths {
		status, resp := doGet(t, r, path)
		if status != http.StatusNotFound {
			t.Fatalf("%s: status = %d, want 404", path, status)
		}
		if resp.Code != "NOT_FOUND" {
			t.Fatalf("%s: envelope code = %q, want NOT_FOUND", path, resp.Code)
		}
		if string(resp.Data) != "null" {
			t.Fatalf("%s: data = %s, want null", path, resp.Data)
		}
	}
}
