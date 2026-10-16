// avatar_test.go 验证用户头像：上传 PNG/JPEG/WEBP、/me 带出 avatar、静态取回
// 字节、非法内容/超限/未登录 400/401、重复上传旧文件清理（package api 内部
// 测试，以便注入临时头像目录 avatarsRoot，与 images_test.go 同模式）。
package api

import (
	"bytes"
	"encoding/json"
	"fmt"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"

	"code-tutorials/backend/internal/store"
)

// jpegMinimal 仅满足服务端魔数校验（FF D8 FF）的最小 JPEG 字节串。
var jpegMinimal = append([]byte{0xFF, 0xD8, 0xFF, 0xE0}, []byte("minimal-jpeg-payload")...)

// webpMinimal 满足 RIFF....WEBP 魔数的最小 WEBP 字节串。
var webpMinimal = append([]byte("RIFF\x24\x00\x00\x00WEBP"), []byte("VP8 minimal")...)

// avatarEnvelope 头像测试内用的响应信封（避免与生产 envelope 重名）。
type avatarEnvelope struct {
	Code    string          `json:"code"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data"`
}

// newAvatarsRouter 打开独立临时库并返回路由引擎，头像根目录指向 t.TempDir()。
func newAvatarsRouter(t *testing.T) *gin.Engine {
	t.Helper()
	old := avatarsRoot
	avatarsRoot = t.TempDir()
	t.Cleanup(func() { avatarsRoot = old })

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

// registerOnRouter 注册用户并返回 token（avatar_test 属 package api，无法使用
// api_test 包里的 registerUserAs，自带等价实现）。
func registerOnRouter(t *testing.T, r *gin.Engine, username string) string {
	t.Helper()
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/register",
		bytes.NewReader([]byte(fmt.Sprintf(`{"username":%q,"password":"secret123"}`, username))))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("register %q: status = %d (body: %s)", username, w.Code, w.Body.String())
	}
	var env struct {
		Data struct {
			Token string `json:"token"`
		} `json:"data"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &env); err != nil {
		t.Fatalf("unmarshal register response: %v", err)
	}
	if env.Data.Token == "" {
		t.Fatalf("register %q: token is empty", username)
	}
	return env.Data.Token
}

// uploadAvatarRaw 发起 multipart 上传请求，返回原始响应记录器；field 为空串
// 表示不带任何文件字段。
func uploadAvatarRaw(t *testing.T, r *gin.Engine, token, field, filename string, content []byte) *httptest.ResponseRecorder {
	t.Helper()
	var buf bytes.Buffer
	mw := multipart.NewWriter(&buf)
	if field != "" {
		fw, err := mw.CreateFormFile(field, filename)
		if err != nil {
			t.Fatalf("create form file: %v", err)
		}
		if _, err := fw.Write(content); err != nil {
			t.Fatalf("write form file: %v", err)
		}
	}
	if err := mw.Close(); err != nil {
		t.Fatalf("close multipart writer: %v", err)
	}
	req := httptest.NewRequest(http.MethodPost, "/api/v1/me/avatar", &buf)
	req.Header.Set("Content-Type", mw.FormDataContentType())
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	return w
}

// uploadAvatar 断言上传成功并返回响应信封。
func uploadAvatar(t *testing.T, r *gin.Engine, token, filename string, content []byte) avatarEnvelope {
	t.Helper()
	w := uploadAvatarRaw(t, r, token, "file", filename, content)
	if w.Code != http.StatusOK {
		t.Fatalf("upload avatar: status = %d (body: %s)", w.Code, w.Body.String())
	}
	var env avatarEnvelope
	if err := json.Unmarshal(w.Body.Bytes(), &env); err != nil {
		t.Fatalf("unmarshal upload response: %v", err)
	}
	if env.Code != "OK" {
		t.Fatalf("upload avatar: code = %q, want OK", env.Code)
	}
	return env
}

// uploadedAvatarOf 解析上传响应里的 user.avatar。
func uploadedAvatarOf(t *testing.T, env avatarEnvelope) string {
	t.Helper()
	var data struct {
		User struct {
			ID     uint   `json:"id"`
			Avatar string `json:"avatar"`
		} `json:"user"`
	}
	if err := json.Unmarshal(env.Data, &data); err != nil {
		t.Fatalf("unmarshal upload data %s: %v", env.Data, err)
	}
	if data.User.ID != 1 {
		t.Fatalf("user.id = %d, want 1", data.User.ID)
	}
	return data.User.Avatar
}

// wantAvatarInvalid 断言 400 AVATAR_INVALID。
func wantAvatarInvalid(t *testing.T, w *httptest.ResponseRecorder) {
	t.Helper()
	if w.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400 (body: %s)", w.Code, w.Body.String())
	}
	var env avatarEnvelope
	if err := json.Unmarshal(w.Body.Bytes(), &env); err != nil || env.Code != "AVATAR_INVALID" {
		t.Fatalf("code = %q err = %v, want AVATAR_INVALID (body: %s)", env.Code, err, w.Body.String())
	}
}

// avatarFiles 返回头像根目录下当前文件名列表。
func avatarFiles(t *testing.T) []string {
	t.Helper()
	entries, err := os.ReadDir(avatarsRoot)
	if err != nil {
		t.Fatalf("read avatarsRoot: %v", err)
	}
	names := make([]string, 0, len(entries))
	for _, e := range entries {
		names = append(names, e.Name())
	}
	return names
}

// userAvatarOf 通过 GET /auth/me 读取当前用户 avatar。
func userAvatarOf(t *testing.T, r *gin.Engine, token string) string {
	t.Helper()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/auth/me", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("me: status = %d (body: %s)", w.Code, w.Body.String())
	}
	var env struct {
		Data struct {
			User struct {
				Avatar string `json:"avatar"`
			} `json:"user"`
		} `json:"data"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &env); err != nil {
		t.Fatalf("unmarshal me response: %v", err)
	}
	return env.Data.User.Avatar
}

// avatarPattern 用户 1 的头像 URL：/avatars/1-{8位hex}.{png|jpg|webp}。
var avatarPattern = regexp.MustCompile(`^/avatars/1-[0-9a-f]{8}[.](png|jpg|webp)$`)

// TestAvatarUploadPNGAndFetch PNG 上传成功：avatar 相对 URL、/me 带出、静态
// 路由 200 取回原字节。
func TestAvatarUploadPNGAndFetch(t *testing.T) {
	r := newAvatarsRouter(t)
	token := registerOnRouter(t, r, "alice")

	// 新注册用户无头像：/me 的 avatar 为空串。
	if got := userAvatarOf(t, r, token); got != "" {
		t.Fatalf("fresh user avatar = %q, want empty", got)
	}

	avatar := uploadedAvatarOf(t, uploadAvatar(t, r, token, "me.png", png1px))
	if !avatarPattern.MatchString(avatar) {
		t.Fatalf("avatar = %q, want /avatars/1-{8hex}.png", avatar)
	}
	if !strings.HasSuffix(avatar, ".png") {
		t.Fatalf("avatar = %q, want .png suffix", avatar)
	}
	if got := userAvatarOf(t, r, token); got != avatar {
		t.Fatalf("me avatar = %q, want %q", got, avatar)
	}

	// 静态取回：200、字节一致、Content-Type 按扩展名。
	status, ct, body := doGetRaw(t, r, avatar)
	if status != http.StatusOK {
		t.Fatalf("GET %s: status = %d", avatar, status)
	}
	if ct != "image/png" {
		t.Fatalf("Content-Type = %q, want image/png", ct)
	}
	if !bytes.Equal(body, png1px) {
		t.Fatalf("avatar bytes mismatch: got %d bytes", len(body))
	}

	// 文件确实写入注入的临时目录。
	files := avatarFiles(t)
	if len(files) != 1 {
		t.Fatalf("files in avatarsRoot = %v, want exactly 1", files)
	}
	raw, err := os.ReadFile(filepath.Join(avatarsRoot, files[0]))
	if err != nil || !bytes.Equal(raw, png1px) {
		t.Fatalf("file on disk mismatch (err = %v, %d bytes)", err, len(raw))
	}
}

// TestAvatarUploadJPEGAndWEBP JPEG/WEBP 魔数接受且扩展名正确。
func TestAvatarUploadJPEGAndWEBP(t *testing.T) {
	r := newAvatarsRouter(t)
	token := registerOnRouter(t, r, "alice")

	for _, tc := range []struct {
		name    string
		content []byte
		ext     string
		ct      string
	}{
		{"jpeg", jpegMinimal, "jpg", "image/jpeg"},
		{"webp", webpMinimal, "webp", "image/webp"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			avatar := uploadedAvatarOf(t, uploadAvatar(t, r, token, "me."+tc.ext, tc.content))
			if !strings.HasSuffix(avatar, "."+tc.ext) {
				t.Fatalf("avatar = %q, want .%s suffix", avatar, tc.ext)
			}
			status, ct, body := doGetRaw(t, r, avatar)
			if status != http.StatusOK || ct != tc.ct || !bytes.Equal(body, tc.content) {
				t.Fatalf("GET avatar: status = %d ct = %q bytes = %d, want 200 %s equal", status, ct, len(body), tc.ct)
			}
		})
	}
}

// TestAvatarInvalidContent 非图片魔数、缺 file 字段、无文件均 400 AVATAR_INVALID。
func TestAvatarInvalidContent(t *testing.T) {
	r := newAvatarsRouter(t)
	token := registerOnRouter(t, r, "alice")

	wantAvatarInvalid(t, uploadAvatarRaw(t, r, token, "file", "note.txt", []byte("plain text, not an image")))
	wantAvatarInvalid(t, uploadAvatarRaw(t, r, token, "other-field", "me.png", png1px))
	wantAvatarInvalid(t, uploadAvatarRaw(t, r, token, "", "", nil))

	// GIF 魔数（GIF89a）不在白名单。
	gif := append([]byte("GIF89a"), make([]byte, 32)...)
	wantAvatarInvalid(t, uploadAvatarRaw(t, r, token, "file", "me.gif", gif))

	// 被拒绝后不落盘、用户 avatar 仍为空。
	if files := avatarFiles(t); len(files) != 0 {
		t.Fatalf("files after rejected uploads = %v, want none", files)
	}
	if got := userAvatarOf(t, r, token); got != "" {
		t.Fatalf("avatar after rejected uploads = %q, want empty", got)
	}
}

// TestAvatarTooLarge 超过 5MB 的文件 400 AVATAR_INVALID（读前按 header.Size 拒绝）。
func TestAvatarTooLarge(t *testing.T) {
	r := newAvatarsRouter(t)
	token := registerOnRouter(t, r, "alice")

	tooLarge := append([]byte{0x89, 'P', 'N', 'G', 0x0d, 0x0a, 0x1a, 0x0a}, make([]byte, avatarMaxBytes)...)
	wantAvatarInvalid(t, uploadAvatarRaw(t, r, token, "file", "big.png", tooLarge))
	if files := avatarFiles(t); len(files) != 0 {
		t.Fatalf("files after oversize upload = %v, want none", files)
	}
}

// TestAvatarRequiresAuth 未带 token 上传 401 AUTH_UNAUTHORIZED。
func TestAvatarRequiresAuth(t *testing.T) {
	r := newAvatarsRouter(t)

	w := uploadAvatarRaw(t, r, "", "file", "me.png", png1px)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401 (body: %s)", w.Code, w.Body.String())
	}
	var env avatarEnvelope
	if err := json.Unmarshal(w.Body.Bytes(), &env); err != nil || env.Code != "AUTH_UNAUTHORIZED" {
		t.Fatalf("code = %q err = %v, want AUTH_UNAUTHORIZED", env.Code, err)
	}
}

// TestAvatarReplaceDeletesOldFile 重复上传后旧文件被清理，avatar 指向新文件。
func TestAvatarReplaceDeletesOldFile(t *testing.T) {
	r := newAvatarsRouter(t)
	token := registerOnRouter(t, r, "alice")

	oldAvatar := uploadedAvatarOf(t, uploadAvatar(t, r, token, "one.png", png1px))
	if files := avatarFiles(t); len(files) != 1 {
		t.Fatalf("files after first upload = %v, want 1", files)
	}
	oldName := oldAvatar[strings.LastIndex(oldAvatar, "/")+1:]
	oldPath := filepath.Join(avatarsRoot, oldName)

	newAvatar := uploadedAvatarOf(t, uploadAvatar(t, r, token, "two.jpg", jpegMinimal))
	newName := newAvatar[strings.LastIndex(newAvatar, "/")+1:]
	if newName == oldName {
		t.Fatalf("new avatar file %q should differ from old %q", newName, oldName)
	}

	// 旧文件已删除，目录只剩新文件。
	if _, err := os.Stat(oldPath); !os.IsNotExist(err) {
		t.Fatalf("old avatar %s still exists (err = %v)", oldPath, err)
	}
	if files := avatarFiles(t); len(files) != 1 || files[0] != newName {
		t.Fatalf("files after replace = %v, want [%s]", files, newName)
	}
	if got := userAvatarOf(t, r, token); !strings.HasSuffix(got, newName) {
		t.Fatalf("me avatar = %q, want suffix %q", got, newName)
	}

	// 旧 URL 不再可取（静态 404 信封）。
	status, _, body := doGetRaw(t, r, "/avatars/"+oldName)
	if status != http.StatusNotFound {
		t.Fatalf("GET old avatar: status = %d, want 404", status)
	}
	assertNotFoundEnvelope(t, "/avatars/"+oldName, body)
}
