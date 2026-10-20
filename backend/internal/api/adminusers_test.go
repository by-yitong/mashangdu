package api_test

// 管理端用户管理测试：列表的分页边界、q 过滤命中与不命中、三类计数与
// lastReadAt（有/无记录）、created_at 降序排序、403 鉴权；删除的级联清理、
// 头像文件删除、再删/非法 id 的 404。

import (
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"testing"

	"github.com/gin-gonic/gin"

	"code-tutorials/backend/internal/model"
)

// adminUsersPageData GET /api/v1/admin/users 响应的 data 结构。
type adminUsersPageData struct {
	Users []struct {
		ID           uint   `json:"id"`
		Username     string `json:"username"`
		Avatar       string `json:"avatar"`
		CreatedAt    string `json:"createdAt"`
		CommentCount int64  `json:"commentCount"`
		LikeCount    int64  `json:"likeCount"`
		RecordCount  int64  `json:"recordCount"`
		LastReadAt   string `json:"lastReadAt"`
	} `json:"users"`
	Total     int64 `json:"total"`
	Page      int   `json:"page"`
	PageSize  int   `json:"pageSize"`
	PageCount int64 `json:"pageCount"`
}

// fetchAdminUsers 拉取管理端用户列表并断言 200 OK。
func fetchAdminUsers(t *testing.T, r *gin.Engine, query string) adminUsersPageData {
	t.Helper()
	status, resp := adminDo(t, r, http.MethodGet, "/api/v1/admin/users"+query, "dev123", nil)
	if status != http.StatusOK || resp.Code != "OK" {
		t.Fatalf("GET admin users%s: status = %d code = %s (data: %s)", query, status, resp.Code, resp.Data)
	}
	var data adminUsersPageData
	if err := json.Unmarshal(resp.Data, &data); err != nil {
		t.Fatalf("unmarshal admin users %s: %v", resp.Data, err)
	}
	return data
}

// TestAdminUsersList 列表：403 鉴权、排序、三类计数与 lastReadAt、
// q 过滤、分页边界与非法参数回落。
func TestAdminUsersList(t *testing.T) {
	t.Setenv("ADMIN_TOKEN", "dev123")
	r := newRouter(t)

	// 403：ADMIN_TOKEN 未设置、缺头、错 token。
	t.Setenv("ADMIN_TOKEN", "")
	status, resp := adminDo(t, r, http.MethodGet, "/api/v1/admin/users", "", nil)
	wantForbidden(t, status, resp, "admin disabled: ADMIN_TOKEN not set")
	t.Setenv("ADMIN_TOKEN", "dev123")
	status, resp = adminDo(t, r, http.MethodGet, "/api/v1/admin/users", "", nil)
	wantForbidden(t, status, resp, "invalid admin token")
	status, resp = adminDo(t, r, http.MethodGet, "/api/v1/admin/users", "wrong-token", nil)
	wantForbidden(t, status, resp, "invalid admin token")

	// 三个用户：alice 有评论/点赞/记录 ×2；bob 无任何活动；carol 仅一条记录。
	tokenA, dataA := registerUser(t, r)
	_, _ = registerUserAs(t, r, "bob", "secret456")
	tokenC, _ := registerUserAs(t, r, "carol", "secret789")
	wantComment201(t, r, tokenA, "go-basics", "hello-world", "alice 的评论")
	doLike(t, r, http.MethodPost, tokenA, "go-basics", "hello-world")
	putRecord(t, r, tokenA, map[string]string{"courseSlug": "go-basics", "chapterSlug": "hello-world"})
	putRecord(t, r, tokenA, map[string]string{"courseSlug": "go-basics", "chapterSlug": "variables"})
	putRecord(t, r, tokenC, map[string]string{"courseSlug": "python-basics", "chapterSlug": "install-repl"})

	// 全量列表：排序 created_at DESC（同秒靠 id 降序，注册顺序即结果顺序）。
	page := fetchAdminUsers(t, r, "")
	if page.Total != 3 || page.Page != 1 || page.PageSize != 20 || page.PageCount != 1 {
		t.Fatalf("page = %+v, want total 3 page 1 pageSize 20 pageCount 1", page)
	}
	for i, want := range []string{"carol", "bob", "alice"} {
		if page.Users[i].Username != want {
			t.Fatalf("users[%d] = %q, want %q (created_at desc)", i, page.Users[i].Username, want)
		}
		assertRFC3339(t, "admin users", "createdAt", page.Users[i].CreatedAt)
	}

	// alice：三类计数与 lastReadAt。
	alice := page.Users[2]
	if alice.ID != dataA.User.ID || alice.Avatar != "" {
		t.Fatalf("alice row = %+v", alice)
	}
	if alice.CommentCount != 1 || alice.LikeCount != 1 || alice.RecordCount != 2 {
		t.Fatalf("alice counts = %+v, want comment 1 like 1 record 2", alice)
	}
	if alice.LastReadAt == "" {
		t.Fatal("alice lastReadAt is empty, want latest read time")
	}
	assertRFC3339(t, "admin users", "lastReadAt", alice.LastReadAt)

	// bob：无活动 → 计数全 0、lastReadAt 空串。
	bob := page.Users[1]
	if bob.CommentCount != 0 || bob.LikeCount != 0 || bob.RecordCount != 0 || bob.LastReadAt != "" {
		t.Fatalf("bob row = %+v, want zero counts and empty lastReadAt", bob)
	}

	// carol：仅记录，无评论/点赞。
	carol := page.Users[0]
	if carol.CommentCount != 0 || carol.LikeCount != 0 || carol.RecordCount != 1 || carol.LastReadAt == "" {
		t.Fatalf("carol row = %+v, want record 1 no comment/like with lastReadAt", carol)
	}
	assertRFC3339(t, "admin users", "carol lastReadAt", carol.LastReadAt)

	// q 过滤：命中 alice、不命中返回空数组（不是 null）。
	page = fetchAdminUsers(t, r, "?q=al")
	if page.Total != 1 || len(page.Users) != 1 || page.Users[0].Username != "alice" {
		t.Fatalf("q=al page = %+v, want only alice", page)
	}
	page = fetchAdminUsers(t, r, "?q=zzz")
	if page.Total != 0 || page.Users == nil || len(page.Users) != 0 || page.PageCount != 0 {
		t.Fatalf("q=zzz page = %+v, want users [] total 0 pageCount 0", page)
	}

	// 分页边界：pageSize=2 切两页，第 2 页只剩最旧的 alice。
	page = fetchAdminUsers(t, r, "?page=1&pageSize=2")
	if page.Total != 3 || page.PageCount != 2 || len(page.Users) != 2 ||
		page.Users[0].Username != "carol" || page.Users[1].Username != "bob" {
		t.Fatalf("page1 size2 = %+v, want [carol bob]", page)
	}
	page = fetchAdminUsers(t, r, "?page=2&pageSize=2")
	if len(page.Users) != 1 || page.Users[0].Username != "alice" {
		t.Fatalf("page2 size2 = %+v, want only alice", page)
	}

	// 非法分页参数回落默认：page=0 → 1，pageSize=0 → 20。
	page = fetchAdminUsers(t, r, "?page=0&pageSize=0")
	if page.Page != 1 || page.PageSize != 20 || len(page.Users) != 3 {
		t.Fatalf("defaulted page = %+v, want page 1 pageSize 20 len 3", page)
	}
}

// TestAdminDeleteUser 删除：级联清空三类业务行、再删/非法 id 404、403。
func TestAdminDeleteUser(t *testing.T) {
	t.Setenv("ADMIN_TOKEN", "dev123")
	r, db := newRouterWithDB(t)

	token, data := registerUser(t, r)
	wantComment201(t, r, token, "go-basics", "hello-world", "即将随用户删除")
	doLike(t, r, http.MethodPost, token, "go-basics", "hello-world")
	putRecord(t, r, token, map[string]string{"courseSlug": "go-basics", "chapterSlug": "hello-world"})

	// 403：错 token。
	if status, resp := adminDo(t, r, http.MethodDelete, "/api/v1/admin/users/"+itoa(data.User.ID), "wrong", nil); status != http.StatusForbidden {
		t.Fatalf("delete with wrong token: status = %d code = %s, want 403", status, resp.Code)
	}

	// 删除：200 {"deleted":true}；用户与评论/点赞/记录全部消失。
	status, resp := adminDo(t, r, http.MethodDelete, "/api/v1/admin/users/"+itoa(data.User.ID), "dev123", nil)
	if status != http.StatusOK || resp.Code != "OK" || string(resp.Data) != `{"deleted":true}` {
		t.Fatalf("delete user: status = %d code = %s data = %s, want 200 OK {\"deleted\":true}", status, resp.Code, resp.Data)
	}
	for name, table := range map[string]interface{}{
		"users":            &model.User{},
		"chapter_comments": &model.ChapterComment{},
		"chapter_likes":    &model.ChapterLike{},
		"reading_records":  &model.ReadingRecord{},
	} {
		var n int64
		if err := db.Model(table).Count(&n).Error; err != nil || n != 0 {
			t.Fatalf("rows in %s after delete = %d (err = %v), want 0", name, n, err)
		}
	}

	// 再删同一 id、id 非数字、id 为 0：均 404 NOT_FOUND "user not found"。
	for _, id := range []string{itoa(data.User.ID), "abc", "0"} {
		status, resp = adminDo(t, r, http.MethodDelete, "/api/v1/admin/users/"+id, "dev123", nil)
		if status != http.StatusNotFound || resp.Code != "NOT_FOUND" || resp.Message != "user not found" {
			t.Fatalf("delete user %q: status = %d code = %s message = %q, want 404 NOT_FOUND user not found",
				id, status, resp.Code, resp.Message)
		}
	}
}

// TestAdminDeleteUserRemovesAvatarFile 头像文件删除：avatarsRoot 相对测试进程
// 工作目录（internal/api），db 直改 avatar 指向 /avatars/<name> 并在
// data/avatars/<name> 造假文件，断言删除用户后文件消失。
func TestAdminDeleteUserRemovesAvatarFile(t *testing.T) {
	t.Setenv("ADMIN_TOKEN", "dev123")
	r, db := newRouterWithDB(t)
	_, data := registerUser(t, r)

	name := itoa(data.User.ID) + "-deadbeef.png"
	avatarDir := filepath.Join("data", "avatars")
	avatarPath := filepath.Join(avatarDir, name)
	if err := os.MkdirAll(avatarDir, 0o755); err != nil {
		t.Fatalf("mkdir avatar dir: %v", err)
	}
	if err := os.WriteFile(avatarPath, []byte("fake png"), 0o644); err != nil {
		t.Fatalf("write fake avatar: %v", err)
	}
	t.Cleanup(func() {
		// 逐层删除本用例创建的文件与目录（目录非空时 Remove 失败被忽略，
		// 不误删他物）；目录不进 git，仅保持测试工作目录整洁。
		_ = os.Remove(avatarPath)
		_ = os.Remove(avatarDir)
		_ = os.Remove("data")
	})
	if err := db.Model(&model.User{}).Where("id = ?", data.User.ID).
		Update("avatar", "/avatars/"+name).Error; err != nil {
		t.Fatalf("set avatar: %v", err)
	}

	if status, resp := adminDo(t, r, http.MethodDelete, "/api/v1/admin/users/"+itoa(data.User.ID), "dev123", nil); status != http.StatusOK || resp.Code != "OK" {
		t.Fatalf("delete user: status = %d code = %s, want 200 OK", status, resp.Code)
	}
	if _, err := os.Stat(avatarPath); !os.IsNotExist(err) {
		t.Fatalf("avatar file %s still exists after user delete (err = %v)", avatarPath, err)
	}
}
