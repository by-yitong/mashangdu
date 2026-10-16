package api_test

// 章节互动接口测试：阅读量自增与 stats、点赞幂等、评论发布/列表分页排序/
// 删除权限/频控/入参校验、管理端评论列表（联表标题与删除兜底）、404 校验，
// 以及阅读量自增不抬 chapters.updated_at（保护 content_version 缓存）。

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"

	"code-tutorials/backend/internal/model"
)

// statsData GET stats 响应的 data 结构。
type statsData struct {
	ViewCount    int64 `json:"viewCount"`
	LikeCount    int64 `json:"likeCount"`
	CommentCount int64 `json:"commentCount"`
	Liked        bool  `json:"liked"`
}

// commentItemDTO 评论单条结构（列表与创建返回共用）。
type commentItemDTO struct {
	ID        uint   `json:"id"`
	UserID    uint   `json:"userId"`
	Username  string `json:"username"`
	Avatar    string `json:"avatar"`
	Content   string `json:"content"`
	CreatedAt string `json:"createdAt"`
}

// commentsPageData 评论列表分页结构。
type commentsPageData struct {
	Comments  []commentItemDTO `json:"comments"`
	Total     int64            `json:"total"`
	Page      int              `json:"page"`
	PageSize  int              `json:"pageSize"`
	PageCount int64            `json:"pageCount"`
}

// chapterPath 拼章节互动路径，如 /api/v1/courses/go-basics/chapters/hello-world/view。
func chapterPath(courseSlug, chapterSlug, action string) string {
	return "/api/v1/courses/" + courseSlug + "/chapters/" + chapterSlug + "/" + action
}

// postView 无认证上报一次阅读，断言 200 并返回 viewCount。
func postView(t *testing.T, r *gin.Engine, courseSlug, chapterSlug string) int64 {
	t.Helper()
	status, resp := userDo(t, r, http.MethodPost, chapterPath(courseSlug, chapterSlug, "view"), "", nil)
	if status != http.StatusOK || resp.Code != "OK" {
		t.Fatalf("POST view: status = %d code = %s, want 200 OK", status, resp.Code)
	}
	var data struct {
		ViewCount int64 `json:"viewCount"`
	}
	if err := json.Unmarshal(resp.Data, &data); err != nil {
		t.Fatalf("unmarshal view data %s: %v", resp.Data, err)
	}
	return data.ViewCount
}

// getStats 拉取章节统计并断言 200。
func getStats(t *testing.T, r *gin.Engine, token, courseSlug, chapterSlug string) statsData {
	t.Helper()
	status, resp := userDo(t, r, http.MethodGet, chapterPath(courseSlug, chapterSlug, "stats"), token, nil)
	if status != http.StatusOK || resp.Code != "OK" {
		t.Fatalf("GET stats: status = %d code = %s, want 200 OK", status, resp.Code)
	}
	var data statsData
	if err := json.Unmarshal(resp.Data, &data); err != nil {
		t.Fatalf("unmarshal stats data %s: %v", resp.Data, err)
	}
	return data
}

// doLike 点赞/取消点赞并断言 200。
func doLike(t *testing.T, r *gin.Engine, method, token, courseSlug, chapterSlug string) (bool, int64) {
	t.Helper()
	status, resp := userDo(t, r, method, chapterPath(courseSlug, chapterSlug, "like"), token, nil)
	if status != http.StatusOK || resp.Code != "OK" {
		t.Fatalf("%s like: status = %d code = %s, want 200 OK", method, status, resp.Code)
	}
	var data struct {
		Liked     bool  `json:"liked"`
		LikeCount int64 `json:"likeCount"`
	}
	if err := json.Unmarshal(resp.Data, &data); err != nil {
		t.Fatalf("unmarshal like data %s: %v", resp.Data, err)
	}
	return data.Liked, data.LikeCount
}

// listComments 拉取评论分页列表并断言 200。
func listComments(t *testing.T, r *gin.Engine, courseSlug, chapterSlug, query string) commentsPageData {
	t.Helper()
	status, resp := userDo(t, r, http.MethodGet, chapterPath(courseSlug, chapterSlug, "comments")+query, "", nil)
	if status != http.StatusOK || resp.Code != "OK" {
		t.Fatalf("GET comments%s: status = %d code = %s, want 200 OK", query, status, resp.Code)
	}
	var data commentsPageData
	if err := json.Unmarshal(resp.Data, &data); err != nil {
		t.Fatalf("unmarshal comments data %s: %v", resp.Data, err)
	}
	return data
}

// postComment 发布评论；返回原始 (status, resp) 以便各用例自行断言。
func postComment(t *testing.T, r *gin.Engine, token, courseSlug, chapterSlug, content string) (int, response) {
	t.Helper()
	return userDo(t, r, http.MethodPost, chapterPath(courseSlug, chapterSlug, "comments"), token,
		map[string]string{"content": content})
}

// wantComment201 发布评论并断言 201，返回单条评论。
func wantComment201(t *testing.T, r *gin.Engine, token, courseSlug, chapterSlug, content string) commentItemDTO {
	t.Helper()
	status, resp := postComment(t, r, token, courseSlug, chapterSlug, content)
	if status != http.StatusCreated || resp.Code != "OK" {
		t.Fatalf("POST comment: status = %d code = %s (data: %s), want 201 OK", status, resp.Code, resp.Data)
	}
	var data struct {
		Comment commentItemDTO `json:"comment"`
	}
	if err := json.Unmarshal(resp.Data, &data); err != nil {
		t.Fatalf("unmarshal comment data %s: %v", resp.Data, err)
	}
	return data.Comment
}

// wantChapterNotFound 断言 404 NOT_FOUND "course or chapter not found"。
func wantChapterNotFound(t *testing.T, status int, resp response) {
	t.Helper()
	if status != http.StatusNotFound || resp.Code != "NOT_FOUND" || resp.Message != "course or chapter not found" {
		t.Fatalf("status = %d code = %s message = %q, want 404 NOT_FOUND course or chapter not found",
			status, resp.Code, resp.Message)
	}
}

func TestChapterViewAndStats(t *testing.T) {
	r := newRouter(t)

	if n := postView(t, r, "go-basics", "hello-world"); n != 1 {
		t.Fatalf("first view: viewCount = %d, want 1", n)
	}
	if n := postView(t, r, "go-basics", "hello-world"); n != 2 {
		t.Fatalf("second view: viewCount = %d, want 2", n)
	}

	// 匿名 stats：liked=false；无效 token 同样放行且 liked=false。
	stats := getStats(t, r, "", "go-basics", "hello-world")
	if stats.ViewCount != 2 || stats.LikeCount != 0 || stats.CommentCount != 0 || stats.Liked {
		t.Fatalf("anonymous stats = %+v, want {2 0 0 false}", stats)
	}
	stats = getStats(t, r, "garbage.token", "go-basics", "hello-world")
	if stats.Liked {
		t.Fatal("stats with invalid token: liked = true, want false")
	}
}

func TestChapterInteractNotFound(t *testing.T) {
	r := newRouter(t)
	token, _ := registerUser(t, r)

	cases := []struct {
		name, method, action, token string
	}{
		{"view missing course", http.MethodPost, "view", ""},
		{"view missing chapter", http.MethodPost, "view", ""},
		{"stats missing chapter", http.MethodGet, "stats", ""},
		{"like missing course", http.MethodPost, "like", token},
		{"unlike missing chapter", http.MethodDelete, "like", token},
		{"comments missing course", http.MethodGet, "comments", ""},
		{"create comment missing chapter", http.MethodPost, "comments", token},
	}
	slugs := [][2]string{
		{"no-such-course", "hello-world"},
		{"go-basics", "no-such-chapter"},
		{"python-basics", "hello-world"}, // 章节不属于该课程
	}
	for _, tc := range cases {
		for _, s := range slugs {
			t.Run(tc.name+" "+s[0]+"/"+s[1], func(t *testing.T) {
				var body interface{}
				if tc.action == "comments" && tc.method == http.MethodPost {
					body = map[string]string{"content": "hi"}
				}
				status, resp := userDo(t, r, tc.method, chapterPath(s[0], s[1], tc.action), tc.token, body)
				wantChapterNotFound(t, status, resp)
			})
		}
	}
}

// TestChapterViewKeepsUpdatedAt 阅读量自增不得抬 chapters.updated_at（否则
// /meta 的 content_version 被抬升、破坏客户端缓存）。
func TestChapterViewKeepsUpdatedAt(t *testing.T) {
	r, db := newRouterWithDB(t)

	var before model.Chapter
	if err := db.Joins("JOIN courses ON courses.id = chapters.course_id").
		Where("courses.slug = ? AND chapters.slug = ?", "go-basics", "hello-world").
		First(&before).Error; err != nil {
		t.Fatalf("load chapter before view: %v", err)
	}
	metaBefore := mustOK(t, r, "/api/v1/meta")

	postView(t, r, "go-basics", "hello-world")
	postView(t, r, "go-basics", "hello-world")

	var after model.Chapter
	if err := db.First(&after, before.ID).Error; err != nil {
		t.Fatalf("load chapter after view: %v", err)
	}
	if !after.UpdatedAt.Equal(before.UpdatedAt) {
		t.Fatalf("chapters.updated_at changed by view: %v -> %v", before.UpdatedAt, after.UpdatedAt)
	}
	if after.ViewCount != before.ViewCount+2 {
		t.Fatalf("view_count = %d, want %d", after.ViewCount, before.ViewCount+2)
	}

	// content_version 同步不受影响。
	var metaData struct {
		ContentVersion string `json:"content_version"`
	}
	if err := json.Unmarshal(metaBefore.Data, &metaData); err != nil {
		t.Fatalf("unmarshal meta: %v", err)
	}
	metaAfter := mustOK(t, r, "/api/v1/meta")
	var after2 struct {
		ContentVersion string `json:"content_version"`
	}
	if err := json.Unmarshal(metaAfter.Data, &after2); err != nil {
		t.Fatalf("unmarshal meta: %v", err)
	}
	if after2.ContentVersion != metaData.ContentVersion {
		t.Fatalf("content_version changed by view: %s -> %s", metaData.ContentVersion, after2.ContentVersion)
	}
}

func TestChapterLikeIdempotent(t *testing.T) {
	r := newRouter(t)
	token, _ := registerUser(t, r)

	// 未登录点赞/取消均 401。
	if status, resp := userDo(t, r, http.MethodPost, chapterPath("go-basics", "hello-world", "like"), "", nil); status != http.StatusUnauthorized || resp.Code != "AUTH_UNAUTHORIZED" {
		t.Fatalf("like without token: status = %d code = %s, want 401 AUTH_UNAUTHORIZED", status, resp.Code)
	}
	if status, resp := userDo(t, r, http.MethodDelete, chapterPath("go-basics", "hello-world", "like"), "", nil); status != http.StatusUnauthorized || resp.Code != "AUTH_UNAUTHORIZED" {
		t.Fatalf("unlike without token: status = %d, want 401", status)
	}

	liked, n := doLike(t, r, http.MethodPost, token, "go-basics", "hello-world")
	if !liked || n != 1 {
		t.Fatalf("first like: liked = %v likeCount = %d, want true 1", liked, n)
	}
	liked, n = doLike(t, r, http.MethodPost, token, "go-basics", "hello-world")
	if !liked || n != 1 {
		t.Fatalf("second like (idempotent): liked = %v likeCount = %d, want true 1", liked, n)
	}

	// 登录后 stats liked=true。
	if stats := getStats(t, r, token, "go-basics", "hello-world"); !stats.Liked || stats.LikeCount != 1 {
		t.Fatalf("stats after like = %+v, want liked=true likeCount=1", stats)
	}

	liked, n = doLike(t, r, http.MethodDelete, token, "go-basics", "hello-world")
	if liked || n != 0 {
		t.Fatalf("unlike: liked = %v likeCount = %d, want false 0", liked, n)
	}
	liked, n = doLike(t, r, http.MethodDelete, token, "go-basics", "hello-world")
	if liked || n != 0 {
		t.Fatalf("second unlike (idempotent): liked = %v likeCount = %d, want false 0", liked, n)
	}
	if stats := getStats(t, r, token, "go-basics", "hello-world"); stats.Liked || stats.LikeCount != 0 {
		t.Fatalf("stats after unlike = %+v, want liked=false likeCount=0", stats)
	}
}

func TestCommentsCreateListDelete(t *testing.T) {
	r := newRouter(t)
	tokenA, dataA := registerUser(t, r)
	tokenB, _ := registerUserAs(t, r, "bob", "secret456")

	// 发布：201，字段齐全（未上传头像时 avatar 为空串）。
	comment := wantComment201(t, r, tokenA, "go-basics", "hello-world", "  写得不错！  ")
	if comment.ID == 0 || comment.UserID != dataA.User.ID || comment.Username != "alice" || comment.Avatar != "" {
		t.Fatalf("comment = %+v", comment)
	}
	if comment.Content != "写得不错！" {
		t.Fatalf("content = %q, want trimmed %q", comment.Content, "写得不错！")
	}
	assertRFC3339(t, "comment createdAt", "createdAt", comment.CreatedAt)

	// 列表：无认证可读；空章节列表给 [] 不给 null。
	page := listComments(t, r, "go-basics", "hello-world", "")
	if page.Total != 1 || len(page.Comments) != 1 || page.Page != 1 || page.PageSize != 20 || page.PageCount != 1 {
		t.Fatalf("page = %+v", page)
	}
	if page.Comments[0] != comment {
		t.Fatalf("listed comment = %+v, want %+v", page.Comments[0], comment)
	}
	empty := listComments(t, r, "go-basics", "goroutine", "")
	if empty.Total != 0 || empty.Comments == nil || len(empty.Comments) != 0 || empty.PageCount != 0 {
		t.Fatalf("empty page = %+v, want comments [] pageCount 0", empty)
	}

	// 删除：他人 403，作者成功，重复删 404。
	if status, resp := userDo(t, r, http.MethodDelete, "/api/v1/comments/999999", tokenB, nil); status != http.StatusNotFound || resp.Code != "NOT_FOUND" {
		t.Fatalf("delete nonexistent: status = %d, want 404", status)
	}
	if status, resp := userDo(t, r, http.MethodDelete, "/api/v1/comments/"+itoa(comment.ID), tokenB, nil); status != http.StatusForbidden || resp.Code != "COMMENT_FORBIDDEN" {
		t.Fatalf("bob deletes alice's comment: status = %d code = %s, want 403 COMMENT_FORBIDDEN", status, resp.Code)
	}
	if status, resp := userDo(t, r, http.MethodDelete, "/api/v1/comments/"+itoa(comment.ID), tokenA, nil); status != http.StatusOK || string(resp.Data) != `{"deleted":1}` {
		t.Fatalf("author deletes: status = %d data = %s, want 200 {\"deleted\":1}", status, resp.Data)
	}
	if status, resp := userDo(t, r, http.MethodDelete, "/api/v1/comments/"+itoa(comment.ID), tokenA, nil); status != http.StatusNotFound || resp.Code != "NOT_FOUND" {
		t.Fatalf("delete again: status = %d code = %s, want 404 NOT_FOUND", status, resp.Code)
	}
	if page := listComments(t, r, "go-basics", "hello-world", ""); page.Total != 0 {
		t.Fatalf("total after delete = %d, want 0", page.Total)
	}
}

// TestCommentsPaginationOrder 三人各发一条，验证最新在前与分页。
func TestCommentsPaginationOrder(t *testing.T) {
	r := newRouter(t)
	// 不同用户各发一条，绕开同用户 10s 频控；id 递增保证同秒内排序稳定。
	tokenBob, _ := registerUserAs(t, r, "bob", "secret456")
	tokenCarol, _ := registerUserAs(t, r, "carol", "secret789")
	tokenDave, _ := registerUserAs(t, r, "dave", "secret012")

	wantComment201(t, r, tokenBob, "go-basics", "hello-world", "first")
	wantComment201(t, r, tokenCarol, "go-basics", "hello-world", "second")
	wantComment201(t, r, tokenDave, "go-basics", "hello-world", "third")

	page := listComments(t, r, "go-basics", "hello-world", "?page=1&pageSize=2")
	if page.Total != 3 || page.PageCount != 2 || len(page.Comments) != 2 {
		t.Fatalf("page1 = %+v", page)
	}
	if page.Comments[0].Content != "third" || page.Comments[1].Content != "second" {
		t.Fatalf("page1 order = [%s %s], want [third second] (created_at desc)",
			page.Comments[0].Content, page.Comments[1].Content)
	}

	page = listComments(t, r, "go-basics", "hello-world", "?page=2&pageSize=2")
	if len(page.Comments) != 1 || page.Comments[0].Content != "first" {
		t.Fatalf("page2 = %+v, want [first]", page)
	}

	// 越界页：空列表 [] 而非 null。
	page = listComments(t, r, "go-basics", "hello-world", "?page=9&pageSize=2")
	if page.Comments == nil || len(page.Comments) != 0 || page.Total != 3 {
		t.Fatalf("page9 = %+v, want comments [] total 3", page)
	}

	// 非法分页参数回落默认：page=0 -> 1，pageSize=0 -> 20。
	page = listComments(t, r, "go-basics", "hello-world", "?page=0&pageSize=0")
	if page.Page != 1 || page.PageSize != 20 || len(page.Comments) != 3 {
		t.Fatalf("defaulted page = %+v, want page=1 pageSize=20 len=3", page)
	}
}

// TestCommentsValidationAndRateLimit 空内容/超长 400，10s 内连发 429。
func TestCommentsValidationAndRateLimit(t *testing.T) {
	r := newRouter(t)
	token, _ := registerUser(t, r)

	cases := []struct {
		name    string
		content string
	}{
		{"empty", ""},
		{"whitespace only", "   \n\t "},
		{"too long", strings.Repeat("字", 1001)},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			status, resp := postComment(t, r, token, "go-basics", "hello-world", tc.content)
			if status != http.StatusBadRequest || resp.Code != "COMMENT_INVALID_INPUT" {
				t.Fatalf("status = %d code = %s, want 400 COMMENT_INVALID_INPUT", status, resp.Code)
			}
		})
	}

	// 被拒的尝试不占用频控窗口：首次合法发布成功。
	wantComment201(t, r, token, "go-basics", "hello-world", "legal one")

	// 同一用户 10s 内再发：429 COMMENT_TOO_FAST。
	status, resp := postComment(t, r, token, "go-basics", "variables", "too fast")
	if status != http.StatusTooManyRequests || resp.Code != "COMMENT_TOO_FAST" {
		t.Fatalf("second comment: status = %d code = %s, want 429 COMMENT_TOO_FAST", status, resp.Code)
	}

	// 其他用户不受影响。
	tokenBob, _ := registerUserAs(t, r, "bob", "secret456")
	wantComment201(t, r, tokenBob, "go-basics", "hello-world", "bob is fine")

	// 未登录发布：401。
	if status, resp := postComment(t, r, "", "go-basics", "hello-world", "anon"); status != http.StatusUnauthorized || resp.Code != "AUTH_UNAUTHORIZED" {
		t.Fatalf("anonymous comment: status = %d code = %s, want 401 AUTH_UNAUTHORIZED", status, resp.Code)
	}
}

func TestAdminCommentsListAndDelete(t *testing.T) {
	t.Setenv("ADMIN_TOKEN", "dev123")
	r := newRouter(t)
	tokenA, _ := registerUser(t, r) // alice
	tokenB, _ := registerUserAs(t, r, "bob", "secret456")

	c1 := wantComment201(t, r, tokenA, "go-basics", "hello-world", "go 讲得好")
	c2 := wantComment201(t, r, tokenB, "python-basics", "install-repl", "python 也不错")

	// 全量：最新在前，联表补齐 username/courseTitle/chapterTitle。
	fetch := func(query string) (commentsPageData, response) {
		t.Helper()
		status, resp := adminDo(t, r, http.MethodGet, "/api/v1/admin/comments"+query, "dev123", nil)
		if status != http.StatusOK || resp.Code != "OK" {
			t.Fatalf("GET admin comments%s: status = %d code = %s", query, status, resp.Code)
		}
		var data commentsPageData
		if err := json.Unmarshal(resp.Data, &data); err != nil {
			t.Fatalf("unmarshal admin comments %s: %v", resp.Data, err)
		}
		return data, resp
	}
	page, resp := fetch("")
	if page.Total != 2 || len(page.Comments) != 2 || page.Page != 1 || page.PageSize != 20 || page.PageCount != 1 {
		t.Fatalf("admin page = %+v (data: %s)", page, resp.Data)
	}

	// 单条字段（admin 返回里携带 courseSlug/courseTitle/chapterSlug/chapterTitle）。
	var probe struct {
		Comments []struct {
			ID           uint   `json:"id"`
			UserID       uint   `json:"userId"`
			Username     string `json:"username"`
			CourseSlug   string `json:"courseSlug"`
			CourseTitle  string `json:"courseTitle"`
			ChapterSlug  string `json:"chapterSlug"`
			ChapterTitle string `json:"chapterTitle"`
			Content      string `json:"content"`
			CreatedAt    string `json:"createdAt"`
		} `json:"comments"`
	}
	if err := json.Unmarshal(resp.Data, &probe); err != nil {
		t.Fatalf("unmarshal admin comments detail: %v", err)
	}
	newest := probe.Comments[0] // bob 的 python 评论
	if newest.ID != c2.ID || newest.Username != "bob" || newest.UserID != c2.UserID {
		t.Fatalf("newest admin comment = %+v, want bob #%d", newest, c2.ID)
	}
	if newest.CourseSlug != "python-basics" || newest.CourseTitle != "Python 基础" ||
		newest.ChapterSlug != "install-repl" || newest.ChapterTitle != "安装与 REPL" {
		t.Fatalf("newest admin comment joins = %+v", newest)
	}
	assertRFC3339(t, "admin comment createdAt", "createdAt", newest.CreatedAt)
	oldest := probe.Comments[1]
	if oldest.CourseTitle != "Go 语言入门" || oldest.ChapterTitle != "Hello World" || oldest.Username != "alice" {
		t.Fatalf("oldest admin comment = %+v", oldest)
	}

	// courseSlug 过滤。
	page, _ = fetch("?courseSlug=go-basics")
	if page.Total != 1 || len(page.Comments) != 1 || page.Comments[0].ID != c1.ID {
		t.Fatalf("filtered page = %+v, want only alice #%d", page, c1.ID)
	}

	// 分页。
	page, _ = fetch("?page=1&pageSize=1")
	if page.Total != 2 || page.PageCount != 2 || len(page.Comments) != 1 {
		t.Fatalf("paged = %+v, want total 2 pageCount 2 len 1", page)
	}

	// 管理员删除任意评论；重复删 404。
	if status, resp := adminDo(t, r, http.MethodDelete, "/api/v1/admin/comments/"+itoa(c1.ID), "dev123", nil); status != http.StatusOK || string(resp.Data) != `{"deleted":1}` {
		t.Fatalf("admin delete: status = %d data = %s, want 200 {\"deleted\":1}", status, resp.Data)
	}
	if status, resp := adminDo(t, r, http.MethodDelete, "/api/v1/admin/comments/"+itoa(c1.ID), "dev123", nil); status != http.StatusNotFound || resp.Code != "NOT_FOUND" {
		t.Fatalf("admin delete again: status = %d, want 404", status)
	}
	page, _ = fetch("?courseSlug=go-basics")
	if page.Total != 0 {
		t.Fatalf("after admin delete total = %d, want 0", page.Total)
	}

	// 管理端鉴权照旧：错 token 403。
	if status, resp := adminDo(t, r, http.MethodGet, "/api/v1/admin/comments", "wrong", nil); status != http.StatusForbidden || resp.Code != "FORBIDDEN" {
		t.Fatalf("wrong admin token: status = %d, want 403", status)
	}
}

// TestAdminCommentsDeletedChapterFallback 课程/章节被删后标题兜底。
func TestAdminCommentsDeletedChapterFallback(t *testing.T) {
	t.Setenv("ADMIN_TOKEN", "dev123")
	r := newRouter(t)
	token, _ := registerUser(t, r)

	wantComment201(t, r, token, "go-basics", "hello-world", "will outlive the chapter")

	// 删除章节后：chapterTitle 兜底 "(已删除章节)"，courseTitle 仍取自课程表。
	if status, _ := adminDo(t, r, http.MethodDelete, "/api/v1/admin/courses/go-basics/chapters/hello-world", "dev123", nil); status != http.StatusOK {
		t.Fatalf("delete chapter: status = %d, want 200", status)
	}
	_, resp := adminDo(t, r, http.MethodGet, "/api/v1/admin/comments?courseSlug=go-basics", "dev123", nil)
	var probe struct {
		Comments []struct {
			CourseTitle  string `json:"courseTitle"`
			ChapterTitle string `json:"chapterTitle"`
		} `json:"comments"`
	}
	if err := json.Unmarshal(resp.Data, &probe); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if len(probe.Comments) != 1 {
		t.Fatalf("comments = %d, want 1", len(probe.Comments))
	}
	if probe.Comments[0].CourseTitle != "Go 语言入门" || probe.Comments[0].ChapterTitle != "(已删除章节)" {
		t.Fatalf("fallback = %+v, want Go 语言入门 / (已删除章节)", probe.Comments[0])
	}

	// 连课程一起删：courseTitle 兜底 "(已删除课程)"。
	if status, _ := adminDo(t, r, http.MethodDelete, "/api/v1/admin/courses/go-basics", "dev123", nil); status != http.StatusOK {
		t.Fatalf("delete course: status = %d, want 200", status)
	}
	_, resp = adminDo(t, r, http.MethodGet, "/api/v1/admin/comments?courseSlug=go-basics", "dev123", nil)
	probe.Comments = nil
	if err := json.Unmarshal(resp.Data, &probe); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if len(probe.Comments) != 1 {
		t.Fatalf("comments after course delete = %d, want 1", len(probe.Comments))
	}
	if probe.Comments[0].CourseTitle != "(已删除课程)" || probe.Comments[0].ChapterTitle != "(已删除章节)" {
		t.Fatalf("fallback = %+v, want (已删除课程) / (已删除章节)", probe.Comments[0])
	}
}

// itoa uint 的十进制字符串（评论 id 拼路径用）。
func itoa(n uint) string {
	return strconv.FormatUint(uint64(n), 10)
}
