package api_test

// 观看记录接口测试：鉴权、PUT upsert（readAt 更新、标题兜底）、课程/章节
// 校验 404、列表排序与 courseTitle（含课程被删兜底）、删单条与清空。

import (
	"encoding/json"
	"net/http"
	"path/filepath"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"code-tutorials/backend/internal/api"
	"code-tutorials/backend/internal/model"
	"code-tutorials/backend/internal/store"
)

// newRouterWithDB 与 newRouter 相同，但把 *gorm.DB 也交还给用例（用于直接
// 回拨 read_at 等确定性操作）。
func newRouterWithDB(t *testing.T) (*gin.Engine, *gorm.DB) {
	t.Helper()
	db, err := store.OpenSeed(filepath.Join(t.TempDir(), "test.db"), t.TempDir())
	if err != nil {
		t.Fatalf("open test store: %v", err)
	}
	t.Cleanup(func() {
		if sqlDB, err := db.DB(); err == nil {
			_ = sqlDB.Close()
		}
	})
	return api.NewRouter(db), db
}

// putRecord 记录一条观看并断言 200 {"ok":true}。
func putRecord(t *testing.T, r *gin.Engine, token string, body map[string]string) {
	t.Helper()
	status, resp := userDo(t, r, http.MethodPut, "/api/v1/records", token, body)
	if status != http.StatusOK || resp.Code != "OK" || string(resp.Data) != `{"ok":true}` {
		t.Fatalf("PUT records %v: status = %d code = %s data = %s, want 200 OK {\"ok\":true}",
			body, status, resp.Code, resp.Data)
	}
}

// listRecords 拉取观看记录列表并断言 200。
func listRecords(t *testing.T, r *gin.Engine, token string) []map[string]interface{} {
	t.Helper()
	status, resp := userDo(t, r, http.MethodGet, "/api/v1/records", token, nil)
	if status != http.StatusOK || resp.Code != "OK" {
		t.Fatalf("GET records: status = %d code = %s, want 200 OK", status, resp.Code)
	}
	var data struct {
		Records []map[string]interface{} `json:"records"`
	}
	if err := json.Unmarshal(resp.Data, &data); err != nil {
		t.Fatalf("unmarshal records data %s: %v", resp.Data, err)
	}
	return data.Records
}

// backdateRecord 把该用户某条记录的 read_at 回拨 d，用于确定性构造时间差。
func backdateRecord(t *testing.T, db *gorm.DB, userID uint, chapterSlug string, d time.Duration) {
	t.Helper()
	if err := db.Model(&model.ReadingRecord{}).
		Where("user_id = ? AND chapter_slug = ?", userID, chapterSlug).
		Update("read_at", time.Now().UTC().Add(-d)).Error; err != nil {
		t.Fatalf("backdate record %s: %v", chapterSlug, err)
	}
}

func TestRecordsRequireAuth(t *testing.T) {
	r := newRouter(t)

	paths := []struct {
		method, path string
	}{
		{http.MethodPut, "/api/v1/records"},
		{http.MethodGet, "/api/v1/records"},
		{http.MethodDelete, "/api/v1/records"},
		{http.MethodDelete, "/api/v1/records/go-basics/hello-world"},
	}
	for _, tc := range paths {
		status, resp := userDo(t, r, tc.method, tc.path, "", map[string]string{
			"courseSlug": "go-basics", "chapterSlug": "hello-world",
		})
		if status != http.StatusUnauthorized || resp.Code != "AUTH_UNAUTHORIZED" {
			t.Fatalf("%s %s without token: status = %d code = %s, want 401 AUTH_UNAUTHORIZED",
				tc.method, tc.path, status, resp.Code)
		}
	}
}

func TestRecordsUpsertUpdatesReadAt(t *testing.T) {
	r, db := newRouterWithDB(t)
	token, data := registerUser(t, r)

	putRecord(t, r, token, map[string]string{
		"courseSlug": "go-basics", "chapterSlug": "hello-world",
	})
	records := listRecords(t, r, token)
	if len(records) != 1 {
		t.Fatalf("records after first PUT = %d, want 1", len(records))
	}

	// 回拨 2 小时后再次 PUT 同一章节：read_at 应被 upsert 为最近时间，
	// 记录不新增；chapterTitle 缺省时用章节表标题兜底。
	backdateRecord(t, db, data.User.ID, "hello-world", 2*time.Hour)
	putRecord(t, r, token, map[string]string{
		"courseSlug": "go-basics", "chapterSlug": "hello-world",
	})
	records = listRecords(t, r, token)
	if len(records) != 1 {
		t.Fatalf("records after re-PUT = %d, want 1 (upsert not insert)", len(records))
	}
	readAt, _ := records[0]["readAt"].(string)
	assertRFC3339(t, "records readAt", "readAt", readAt)
	parsed, err := time.Parse(time.RFC3339, readAt)
	if err != nil {
		t.Fatalf("parse readAt: %v", err)
	}
	if time.Since(parsed) > time.Minute {
		t.Fatalf("readAt = %s, want within last minute (upsert should refresh read_at)", readAt)
	}
	if title, _ := records[0]["chapterTitle"].(string); title != "Hello World" {
		t.Fatalf("chapterTitle fallback = %q, want %q (chapter table title)", title, "Hello World")
	}

	// 显式提供 chapterTitle 时以其为准。
	putRecord(t, r, token, map[string]string{
		"courseSlug": "go-basics", "chapterSlug": "hello-world", "chapterTitle": "自定义标题",
	})
	records = listRecords(t, r, token)
	if title, _ := records[0]["chapterTitle"].(string); title != "自定义标题" {
		t.Fatalf("chapterTitle = %q, want 自定义标题", title)
	}
}

func TestRecordsUpsertNotFound(t *testing.T) {
	r := newRouter(t)
	token, _ := registerUser(t, r)

	cases := []struct {
		name string
		body map[string]string
	}{
		{"missing course", map[string]string{"courseSlug": "no-such-course", "chapterSlug": "hello-world"}},
		{"missing chapter", map[string]string{"courseSlug": "go-basics", "chapterSlug": "no-such-chapter"}},
		{"chapter of another course", map[string]string{"courseSlug": "python-basics", "chapterSlug": "hello-world"}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			status, resp := userDo(t, r, http.MethodPut, "/api/v1/records", token, tc.body)
			if status != http.StatusNotFound || resp.Code != "NOT_FOUND" {
				t.Fatalf("PUT records: status = %d code = %s, want 404 NOT_FOUND", status, resp.Code)
			}
		})
	}

	// 失败的 PUT 不得留下任何记录。
	if records := listRecords(t, r, token); len(records) != 0 {
		t.Fatalf("records after failed PUTs = %d, want 0", len(records))
	}
}

func TestRecordsListOrderAndDeletedCourse(t *testing.T) {
	t.Setenv("ADMIN_TOKEN", "dev123")
	r, db := newRouterWithDB(t)
	token, data := registerUser(t, r)

	// 依次观看 3 章：hello-world（最旧）→ variables → install-repl（最新）。
	putRecord(t, r, token, map[string]string{"courseSlug": "go-basics", "chapterSlug": "hello-world"})
	backdateRecord(t, db, data.User.ID, "hello-world", 2*time.Hour)
	putRecord(t, r, token, map[string]string{"courseSlug": "go-basics", "chapterSlug": "variables"})
	backdateRecord(t, db, data.User.ID, "variables", time.Hour)
	putRecord(t, r, token, map[string]string{"courseSlug": "python-basics", "chapterSlug": "install-repl"})

	records := listRecords(t, r, token)
	if len(records) != 3 {
		t.Fatalf("records = %d, want 3", len(records))
	}
	wantOrder := []string{"install-repl", "variables", "hello-world"}
	for i, want := range wantOrder {
		if got, _ := records[i]["chapterSlug"].(string); got != want {
			t.Fatalf("records[%d].chapterSlug = %q, want %q (readAt desc)", i, got, want)
		}
	}
	if title, _ := records[0]["courseTitle"].(string); title != "Python 基础" {
		t.Fatalf("courseTitle = %q, want %q", title, "Python 基础")
	}
	if title, _ := records[1]["courseTitle"].(string); title != "Go 语言入门" {
		t.Fatalf("courseTitle = %q, want %q", title, "Go 语言入门")
	}

	// 删除 go-basics 课程后：记录仍在，courseTitle 兜底为 "(已删除课程)"。
	if status, resp := adminDo(t, r, http.MethodDelete, "/api/v1/admin/courses/go-basics", "dev123", nil); status != http.StatusOK {
		t.Fatalf("delete course: status = %d code = %s", status, resp.Code)
	}
	records = listRecords(t, r, token)
	if len(records) != 3 {
		t.Fatalf("records after course delete = %d, want 3", len(records))
	}
	for i, want := range []string{"Python 基础", "(已删除课程)", "(已删除课程)"} {
		if got, _ := records[i]["courseTitle"].(string); got != want {
			t.Fatalf("records[%d].courseTitle = %q, want %q", i, got, want)
		}
	}
}

func TestRecordsDelete(t *testing.T) {
	r := newRouter(t)
	token, _ := registerUser(t, r)

	putRecord(t, r, token, map[string]string{"courseSlug": "go-basics", "chapterSlug": "hello-world"})
	putRecord(t, r, token, map[string]string{"courseSlug": "go-basics", "chapterSlug": "variables"})

	// 删单条：{"deleted":1}；重复删：{"deleted":0}。
	status, resp := userDo(t, r, http.MethodDelete, "/api/v1/records/go-basics/hello-world", token, nil)
	if status != http.StatusOK || resp.Code != "OK" || string(resp.Data) != `{"deleted":1}` {
		t.Fatalf("delete one: status = %d code = %s data = %s, want 200 {\"deleted\":1}", status, resp.Code, resp.Data)
	}
	status, resp = userDo(t, r, http.MethodDelete, "/api/v1/records/go-basics/hello-world", token, nil)
	if status != http.StatusOK || string(resp.Data) != `{"deleted":0}` {
		t.Fatalf("delete one again: status = %d data = %s, want 200 {\"deleted\":0}", status, resp.Data)
	}
	if records := listRecords(t, r, token); len(records) != 1 {
		t.Fatalf("records after delete one = %d, want 1", len(records))
	}

	// 清空：{"deleted":1}；再清空：{"deleted":0}。
	status, resp = userDo(t, r, http.MethodDelete, "/api/v1/records", token, nil)
	if status != http.StatusOK || resp.Code != "OK" || string(resp.Data) != `{"deleted":1}` {
		t.Fatalf("clear all: status = %d code = %s data = %s, want 200 {\"deleted\":1}", status, resp.Code, resp.Data)
	}
	if records := listRecords(t, r, token); len(records) != 0 {
		t.Fatalf("records after clear = %d, want 0", len(records))
	}
	status, resp = userDo(t, r, http.MethodDelete, "/api/v1/records", token, nil)
	if status != http.StatusOK || string(resp.Data) != `{"deleted":0}` {
		t.Fatalf("clear again: status = %d data = %s, want 200 {\"deleted\":0}", status, resp.Data)
	}
}

// TestRecordsArePerUser 验证不同用户记录互不可见。
func TestRecordsArePerUser(t *testing.T) {
	r := newRouter(t)
	tokenA, _ := registerUserAs(t, r, "alice", "secret123")
	tokenB, _ := registerUserAs(t, r, "bob", "secret456")

	putRecord(t, r, tokenA, map[string]string{"courseSlug": "go-basics", "chapterSlug": "hello-world"})
	if records := listRecords(t, r, tokenB); len(records) != 0 {
		t.Fatalf("bob sees alice's records: %d, want 0", len(records))
	}

	// bob 删不到 alice 的记录。
	status, resp := userDo(t, r, http.MethodDelete, "/api/v1/records/go-basics/hello-world", tokenB, nil)
	if status != http.StatusOK || string(resp.Data) != `{"deleted":0}` {
		t.Fatalf("bob deletes alice's record: status = %d data = %s, want {\"deleted\":0}", status, resp.Data)
	}
	if records := listRecords(t, r, tokenA); len(records) != 1 {
		t.Fatalf("alice records after bob's delete = %d, want 1", len(records))
	}
}
