package api_test

// 管理端概况统计测试：空库各计数全 0 且三个数组为 []（不是 null）、
// contentVersion 与 /meta 同语义、注册/建课/阅读/评论/点赞后的各计数与
// topChapters 排序、recentUsers/recentComments 排序与删除兜底文案、403 鉴权。

import (
	"encoding/json"
	"net/http"
	"path/filepath"
	"testing"

	"github.com/gin-gonic/gin"

	"code-tutorials/backend/internal/api"
	"code-tutorials/backend/internal/model"
	"code-tutorials/backend/internal/store"
)

// adminStatsData GET /api/v1/admin/stats 响应的 data 结构。
type adminStatsData struct {
	CourseCount    int64  `json:"courseCount"`
	ChapterCount   int64  `json:"chapterCount"`
	TotalViews     int64  `json:"totalViews"`
	UserCount      int64  `json:"userCount"`
	CommentCount   int64  `json:"commentCount"`
	LikeCount      int64  `json:"likeCount"`
	ContentVersion string `json:"contentVersion"`
	TopChapters []struct {
		CourseSlug   string `json:"courseSlug"`
		CourseTitle  string `json:"courseTitle"`
		ChapterSlug  string `json:"chapterSlug"`
		ChapterTitle string `json:"chapterTitle"`
		ViewCount    int64  `json:"viewCount"`
	} `json:"topChapters"`
	RecentUsers []struct {
		ID        uint   `json:"id"`
		Username  string `json:"username"`
		Avatar    string `json:"avatar"`
		CreatedAt string `json:"createdAt"`
	} `json:"recentUsers"`
	RecentComments []struct {
		ID           uint   `json:"id"`
		UserID       uint   `json:"userId"`
		Username     string `json:"username"`
		CourseSlug   string `json:"courseSlug"`
		ChapterSlug  string `json:"chapterSlug"`
		ChapterTitle string `json:"chapterTitle"`
		Content      string `json:"content"`
		CreatedAt    string `json:"createdAt"`
	} `json:"recentComments"`
}

// newEmptyRouter 打开无种子的空库并返回路由引擎（空库 stats 全 0 断言用）。
// store.Open 会按候选路径自动探测磁盘 seeddata（测试 cwd 下 ../store/seeddata
// 存在），故显式指定一个不含 courses.json 的临时种子目录，保证真正的空库。
func newEmptyRouter(t *testing.T) *gin.Engine {
	t.Helper()
	db, err := store.OpenSeed(filepath.Join(t.TempDir(), "empty.db"), t.TempDir())
	if err != nil {
		t.Fatalf("open empty store: %v", err)
	}
	t.Cleanup(func() {
		if sqlDB, err := db.DB(); err == nil {
			_ = sqlDB.Close()
		}
	})
	return api.NewRouter(db)
}

// fetchAdminStats 拉取管理端概况并断言 200 OK。
func fetchAdminStats(t *testing.T, r *gin.Engine) adminStatsData {
	t.Helper()
	status, resp := adminDo(t, r, http.MethodGet, "/api/v1/admin/stats", "dev123", nil)
	if status != http.StatusOK || resp.Code != "OK" {
		t.Fatalf("GET admin stats: status = %d code = %s (data: %s)", status, resp.Code, resp.Data)
	}
	var data adminStatsData
	if err := json.Unmarshal(resp.Data, &data); err != nil {
		t.Fatalf("unmarshal admin stats %s: %v", resp.Data, err)
	}
	return data
}

// metaContentVersion 取 GET /meta 的 content_version，供同语义比对。
func metaContentVersion(t *testing.T, r *gin.Engine) string {
	t.Helper()
	resp := mustOK(t, r, "/api/v1/meta")
	var data struct {
		ContentVersion string `json:"content_version"`
	}
	if err := json.Unmarshal(resp.Data, &data); err != nil {
		t.Fatalf("unmarshal meta: %v", err)
	}
	return data.ContentVersion
}

// TestAdminStatsEmptyDB 空库：各计数全 0、数组为 [] 而非 null、
// contentVersion 与 /meta 一致。
func TestAdminStatsEmptyDB(t *testing.T) {
	t.Setenv("ADMIN_TOKEN", "dev123")
	r := newEmptyRouter(t)

	stats := fetchAdminStats(t, r)
	if stats.CourseCount != 0 || stats.ChapterCount != 0 || stats.TotalViews != 0 ||
		stats.UserCount != 0 || stats.CommentCount != 0 || stats.LikeCount != 0 {
		t.Fatalf("empty db stats = %+v, want all zero", stats)
	}
	if stats.TopChapters == nil || len(stats.TopChapters) != 0 {
		t.Fatalf("topChapters = %#v, want [] (not null)", stats.TopChapters)
	}
	if stats.RecentUsers == nil || len(stats.RecentUsers) != 0 {
		t.Fatalf("recentUsers = %#v, want [] (not null)", stats.RecentUsers)
	}
	if stats.RecentComments == nil || len(stats.RecentComments) != 0 {
		t.Fatalf("recentComments = %#v, want [] (not null)", stats.RecentComments)
	}
	if stats.ContentVersion != metaContentVersion(t, r) {
		t.Fatalf("contentVersion = %q, want same as /meta %q", stats.ContentVersion, metaContentVersion(t, r))
	}
}

// TestAdminStatsWithActivity 注册用户 + 管理端建课建章 + 阅读/评论/点赞后：
// 各计数、topChapters 排序、recentUsers/recentComments 排序与兜底文案、
// 删除章节/用户后的回落与兜底。
func TestAdminStatsWithActivity(t *testing.T) {
	t.Setenv("ADMIN_TOKEN", "dev123")
	r, db := newRouterWithDB(t)

	// 403：缺头、错 token。
	status, resp := adminDo(t, r, http.MethodGet, "/api/v1/admin/stats", "", nil)
	wantForbidden(t, status, resp, "invalid admin token")
	status, resp = adminDo(t, r, http.MethodGet, "/api/v1/admin/stats", "wrong", nil)
	wantForbidden(t, status, resp, "invalid admin token")

	tokenA, dataA := registerUser(t, r)                    // alice
	tokenB, dataB := registerUserAs(t, r, "bob", "secret456") // bob

	// 管理端新建一门课程与一个章节（不产生阅读量）。
	if status, resp = adminDo(t, r, http.MethodPost, "/api/v1/admin/courses", "dev123", newCourseBody("rust-basics")); status != http.StatusOK {
		t.Fatalf("create course: status = %d code = %s", status, resp.Code)
	}
	if status, resp = adminDo(t, r, http.MethodPost, "/api/v1/admin/courses/rust-basics/chapters", "dev123", map[string]interface{}{
		"slug": "ownership", "title": "所有权入门",
	}); status != http.StatusOK {
		t.Fatalf("create chapter: status = %d code = %s", status, resp.Code)
	}

	// 阅读：hello-world ×3、variables ×5 → totalViews 8。
	for i := 0; i < 3; i++ {
		postView(t, r, "go-basics", "hello-world")
	}
	for i := 0; i < 5; i++ {
		postView(t, r, "go-basics", "variables")
	}

	// 互动：alice/bob 各评论+点赞一章，各留一条观看记录。
	wantComment201(t, r, tokenA, "go-basics", "hello-world", "alice 的评论")
	doLike(t, r, http.MethodPost, tokenA, "go-basics", "hello-world")
	putRecord(t, r, tokenA, map[string]string{"courseSlug": "go-basics", "chapterSlug": "hello-world"})
	wantComment201(t, r, tokenB, "go-basics", "variables", "bob 的评论")
	doLike(t, r, http.MethodPost, tokenB, "go-basics", "variables")
	putRecord(t, r, tokenB, map[string]string{"courseSlug": "go-basics", "chapterSlug": "variables"})

	// 直插一条孤儿评论（user_id 无对应用户行），验证用户名兜底文案。
	orphan := model.ChapterComment{UserID: 424242, CourseSlug: "go-basics", ChapterSlug: "goroutine", Content: "orphan"}
	if err := db.Create(&orphan).Error; err != nil {
		t.Fatalf("create orphan comment: %v", err)
	}

	stats := fetchAdminStats(t, r)
	if stats.CourseCount != 3 || stats.ChapterCount != 6 || stats.TotalViews != 8 ||
		stats.UserCount != 2 || stats.CommentCount != 3 || stats.LikeCount != 2 {
		t.Fatalf("stats = %+v, want course 3 chapter 6 views 8 user 2 comment 3 like 2", stats)
	}

	// topChapters：仅 view_count > 0，按 view_count 降序。
	if len(stats.TopChapters) != 2 {
		t.Fatalf("topChapters = %+v, want 2 (view_count > 0 only)", stats.TopChapters)
	}
	if stats.TopChapters[0].ChapterSlug != "variables" || stats.TopChapters[0].ViewCount != 5 ||
		stats.TopChapters[1].ChapterSlug != "hello-world" || stats.TopChapters[1].ViewCount != 3 {
		t.Fatalf("topChapters = %+v, want variables(5) then hello-world(3)", stats.TopChapters)
	}
	if stats.TopChapters[0].CourseSlug != "go-basics" || stats.TopChapters[0].CourseTitle != "Go 语言入门" ||
		stats.TopChapters[0].ChapterTitle != "变量与基本类型" {
		t.Fatalf("topChapters[0] joins = %+v", stats.TopChapters[0])
	}

	// recentUsers：最新注册在前（同秒靠 id 降序，bob 稳定第一）。
	if len(stats.RecentUsers) != 2 || stats.RecentUsers[0].Username != "bob" || stats.RecentUsers[1].Username != "alice" {
		t.Fatalf("recentUsers = %+v, want [bob alice]", stats.RecentUsers)
	}
	if stats.RecentUsers[1].ID != dataA.User.ID {
		t.Fatalf("recentUsers[1].id = %d, want %d", stats.RecentUsers[1].ID, dataA.User.ID)
	}
	assertRFC3339(t, "admin stats", "recentUsers.createdAt", stats.RecentUsers[0].CreatedAt)

	// recentComments：孤儿(id 最大) → bob(variables) → alice(hello-world)。
	if len(stats.RecentComments) != 3 {
		t.Fatalf("recentComments = %+v, want 3", stats.RecentComments)
	}
	want := []struct{ username, chapterTitle, content string }{
		{"(已删除用户)", "goroutine 并发入门", "orphan"},
		{"bob", "变量与基本类型", "bob 的评论"},
		{"alice", "Hello World", "alice 的评论"},
	}
	for i, w := range want {
		got := stats.RecentComments[i]
		if got.Username != w.username || got.ChapterTitle != w.chapterTitle || got.Content != w.content {
			t.Fatalf("recentComments[%d] = %+v, want username=%q chapterTitle=%q content=%q",
				i, got, w.username, w.chapterTitle, w.content)
		}
		assertRFC3339(t, "admin stats", "recentComments.createdAt", got.CreatedAt)
	}

	// contentVersion 与 /meta 完全一致。
	if stats.ContentVersion != metaContentVersion(t, r) {
		t.Fatalf("contentVersion = %q, want same as /meta %q", stats.ContentVersion, metaContentVersion(t, r))
	}

	// 删除章节 variables：计数回落，bob 评论的 chapterTitle 兜底 "(已删除章节)"。
	if status, resp = adminDo(t, r, http.MethodDelete, "/api/v1/admin/courses/go-basics/chapters/variables", "dev123", nil); status != http.StatusOK {
		t.Fatalf("delete chapter: status = %d code = %s", status, resp.Code)
	}
	stats = fetchAdminStats(t, r)
	if stats.ChapterCount != 5 || stats.TotalViews != 3 || len(stats.TopChapters) != 1 {
		t.Fatalf("stats after chapter delete = %+v, want chapter 5 views 3 topChapters 1", stats)
	}
	if got := stats.RecentComments[1]; got.Content != "bob 的评论" || got.ChapterTitle != "(已删除章节)" || got.Username != "bob" {
		t.Fatalf("recentComments[1] after chapter delete = %+v, want bob /(已删除章节)/bob 的评论", got)
	}

	// 删除用户 bob（走 18b）：其评论/点赞级联消失，计数继续回落。
	if status, resp = adminDo(t, r, http.MethodDelete, "/api/v1/admin/users/"+itoa(dataB.User.ID), "dev123", nil); status != http.StatusOK {
		t.Fatalf("delete user bob: status = %d code = %s", status, resp.Code)
	}
	stats = fetchAdminStats(t, r)
	if stats.UserCount != 1 || stats.CommentCount != 2 || stats.LikeCount != 1 {
		t.Fatalf("stats after user delete = %+v, want user 1 comment 2 like 1", stats)
	}
	if len(stats.RecentUsers) != 1 || stats.RecentUsers[0].Username != "alice" {
		t.Fatalf("recentUsers after user delete = %+v, want [alice]", stats.RecentUsers)
	}
	if len(stats.RecentComments) != 2 || stats.RecentComments[0].Content != "orphan" ||
		stats.RecentComments[1].Username != "alice" {
		t.Fatalf("recentComments after user delete = %+v, want [orphan alice 的评论]", stats.RecentComments)
	}
}
