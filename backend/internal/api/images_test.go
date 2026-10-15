// images_test.go 验证 GET /images/*filepath 教程图片静态托管（package api
// 内部测试，以便注入临时图片目录 imagesRoot）。
package api

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"github.com/gin-gonic/gin"

	"code-tutorials/backend/internal/store"
)

// png1px 最小合法 PNG（1x1 透明像素）。
var png1px = []byte{
	0x89, 'P', 'N', 'G', 0x0d, 0x0a, 0x1a, 0x0a,
	0x00, 0x00, 0x00, 0x0d, 'I', 'H', 'D', 'R',
	0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00,
	0x1f, 0x15, 0xc4, 0x89,
	0x00, 0x00, 0x00, 0x0a, 'I', 'D', 'A', 'T',
	0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01,
	0x0d, 0x0a, 0x2d, 0xb4,
	0x00, 0x00, 0x00, 0x00, 'I', 'E', 'N', 'D',
	0xae, 0x42, 0x60, 0x82,
}

// newImagesRouter 打开独立临时库并返回路由引擎，图片根目录指向 t.TempDir()。
func newImagesRouter(t *testing.T) *gin.Engine {
	t.Helper()
	old := imagesRoot
	imagesRoot = t.TempDir()
	t.Cleanup(func() { imagesRoot = old })

	db, err := store.OpenSeed(filepath.Join(t.TempDir(), "test.db"), t.TempDir())
	if err != nil {
		t.Fatalf("open test store: %v", err)
	}
	t.Cleanup(func() {
		if sqlDB, err := db.DB(); err == nil {
			_ = sqlDB.Close()
		}
	})
	return NewRouter(db)
}

// doGetRaw 发起 GET 并返回状态码、Content-Type 与响应体。
func doGetRaw(t *testing.T, r *gin.Engine, path string) (int, string, []byte) {
	t.Helper()
	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest(http.MethodGet, path, nil))
	return w.Code, w.Header().Get("Content-Type"), w.Body.Bytes()
}

// TestImagesStaticServing 已落盘图片返回 200，Content-Type 按扩展名映射。
func TestImagesStaticServing(t *testing.T) {
	r := newImagesRouter(t)

	deepDir := filepath.Join(imagesRoot, "hello-algo", "sorting", "quick_sort.assets")
	if err := os.MkdirAll(deepDir, 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	if err := os.WriteFile(filepath.Join(deepDir, "step1.png"), png1px, 0o644); err != nil {
		t.Fatalf("write png: %v", err)
	}
	if err := os.WriteFile(filepath.Join(imagesRoot, "pic.svg"), []byte(`<svg xmlns="http://www.w3.org/2000/svg"/>`), 0o644); err != nil {
		t.Fatalf("write svg: %v", err)
	}

	cases := []struct {
		path        string
		contentType string
		body        []byte
	}{
		{"/images/hello-algo/sorting/quick_sort.assets/step1.png", "image/png", png1px},
		{"/images/pic.svg", "image/svg+xml", []byte(`<svg xmlns="http://www.w3.org/2000/svg"/>`)},
	}
	for _, tc := range cases {
		status, ct, body := doGetRaw(t, r, tc.path)
		if status != http.StatusOK {
			t.Fatalf("%s: status = %d, want 200 (body: %s)", tc.path, status, body)
		}
		if ct != tc.contentType {
			t.Fatalf("%s: Content-Type = %q, want %q", tc.path, ct, tc.contentType)
		}
		if string(body) != string(tc.body) {
			t.Fatalf("%s: body mismatch, got %d bytes", tc.path, len(body))
		}
	}
}

// TestImagesStaticNotFound 文件缺失、目录未落盘、.. 穿越一律 404 统一信封。
func TestImagesStaticNotFound(t *testing.T) {
	r := newImagesRouter(t)

	cases := []string{
		"/images/no-such.png",                                    // 文件不存在
		"/images/hello-algo/sorting/quick_sort.assets/step1.png", // 目录未落盘（整树不存在）
		"/images/../main.go",                                     // .. 穿越，禁止越出图片根目录
		"/images/../api/v1/courses",                              // .. 穿越到 API 路由，同样不可达
	}
	for _, path := range cases {
		status, _, body := doGetRaw(t, r, path)
		if status != http.StatusNotFound {
			t.Fatalf("%s: status = %d, want 404 (body: %s)", path, status, body)
		}
		assertNotFoundEnvelope(t, path, body)
	}
}

// TestImagesWithoutRootDir 目录完全不存在时不影响其余路由，请求统一 404。
func TestImagesWithoutRootDir(t *testing.T) {
	// newImagesRouter 已用全新 t.TempDir() 作图片根目录（不存在任何文件），
	// 此处只需再确认 /api/v1 未被 /images 挂载影响。
	r := newImagesRouter(t)

	status, _, body := doGetRaw(t, r, "/images/whatever.png")
	if status != http.StatusNotFound {
		t.Fatalf("empty root: status = %d, want 404", status)
	}
	assertNotFoundEnvelope(t, "/images/whatever.png", body)

	// 目录列表禁用：请求图片根目录本身（/images/）同样 404，不暴露文件清单。
	status, _, body = doGetRaw(t, r, "/images/")
	if status != http.StatusNotFound {
		t.Fatalf("/images/: status = %d, want 404 (body: %s)", status, body)
	}

	// 既有 API 行为不变：未知 /api/v1 路由仍走统一 404 信封。
	status, _, body = doGetRaw(t, r, "/api/v1/no-such-route")
	if status != http.StatusNotFound {
		t.Fatalf("/api/v1/no-such-route: status = %d, want 404", status)
	}
	assertNotFoundEnvelope(t, "/api/v1/no-such-route", body)
}

// assertNotFoundEnvelope 断言响应体为统一 404 JSON 信封。
func assertNotFoundEnvelope(t *testing.T, path string, body []byte) {
	t.Helper()
	want := `{"code":"NOT_FOUND","message":"not found","data":null}`
	if string(body) != want {
		t.Fatalf("%s: body = %s, want %s", path, body, want)
	}
}
