package api

// 章节互动接口：阅读量（view）、统计（stats，可选 Bearer）、点赞（like，幂等）、
// 评论（发布/列表/删除，10s 频控）以及管理端评论列表/删除。
//
// 课程/章节合法性校验走 records.go 的联表模式：courseSlug 必须存在、chapterSlug
// 必须属于该课程，否则 404 NOT_FOUND "course or chapter not found"。
//
// 阅读量自增必须用 UpdateColumn + gorm.Expr（只动 view_count，不抬 updated_at，
// 否则 /meta 的 content_version 会被抬升、破坏客户端缓存）。

import (
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"code-tutorials/backend/internal/model"
)

// commentCooldown 同一用户两次评论的最小间隔。
const commentCooldown = 10 * time.Second

// deletedChapterTitle 章节/课程被删后管理端评论列表展示的兜底标题。
const deletedChapterTitle = "(已删除章节)"

// deletedUsername 评论作者被删后列表展示的兜底用户名。
const deletedUsername = "(已删除用户)"

// commentItem 评论对外结构（用户端列表与创建返回共用）。
type commentItem struct {
	ID        uint   `json:"id"`
	UserID    uint   `json:"userId"`
	Username  string `json:"username"`
	Avatar    string `json:"avatar"`
	Content   string `json:"content"`
	CreatedAt string `json:"createdAt"`
}

// adminCommentItem 管理端评论列表单条结构（联表补齐用户名与课程/章节标题）。
type adminCommentItem struct {
	ID           uint   `json:"id"`
	UserID       uint   `json:"userId"`
	Username     string `json:"username"`
	CourseSlug   string `json:"courseSlug"`
	CourseTitle  string `json:"courseTitle"`
	ChapterSlug  string `json:"chapterSlug"`
	ChapterTitle string `json:"chapterTitle"`
	Content      string `json:"content"`
	CreatedAt    string `json:"createdAt"`
}

// tooFastComment 频控：同一用户距上次成功评论不足 10s 时返回 true（本次不
// 刷新时间戳）；进程内 map 实现，重启清零可接受。
func (s *Server) tooFastComment(userID uint) bool {
	now := time.Now()
	s.commentMu.Lock()
	defer s.commentMu.Unlock()
	if last, ok := s.lastCommentAt[userID]; ok && now.Sub(last) < commentCooldown {
		return true
	}
	s.lastCommentAt[userID] = now
	return false
}

// findChapterBySlugs 联表校验课程存在且章节属于该课程（records.go 同款模式）。
func (s *Server) findChapterBySlugs(courseSlug, chapterSlug string) (model.Chapter, error) {
	var chapter model.Chapter
	err := s.db.Joins("JOIN courses ON courses.id = chapters.course_id").
		Where("courses.slug = ? AND chapters.slug = ?", courseSlug, chapterSlug).
		First(&chapter).Error
	return chapter, err
}

// chapterOrAbort 校验路径中的课程/章节；不合法时已写响应并返回 false。
func (s *Server) chapterOrAbort(c *gin.Context) (model.Chapter, bool) {
	chapter, err := s.findChapterBySlugs(c.Param("slug"), c.Param("chapterSlug"))
	if errors.Is(err, gorm.ErrRecordNotFound) {
		fail(c, http.StatusNotFound, "NOT_FOUND", "course or chapter not found")
		return chapter, false
	}
	if err != nil {
		s.internalError(c, err)
		return chapter, false
	}
	return chapter, true
}

// atoiDefault 解析整数参数，空串或非法时取默认值。
func atoiDefault(s string, def int) int {
	if s == "" {
		return def
	}
	n, err := strconv.Atoi(s)
	if err != nil {
		return def
	}
	return n
}

// pageParams 解析分页参数：page ≥1（默认 1）、pageSize 1..50（默认 20），
// 非法值回落默认。
func pageParams(c *gin.Context) (page, pageSize int) {
	page = atoiDefault(c.Query("page"), 1)
	if page < 1 {
		page = 1
	}
	pageSize = atoiDefault(c.Query("pageSize"), 20)
	if pageSize < 1 {
		pageSize = 20
	}
	if pageSize > 50 {
		pageSize = 50
	}
	return page, pageSize
}

// pageCount 计算 ceil(total/pageSize)；total=0 时为 0。
func pageCount(total int64, pageSize int) int64 {
	return (total + int64(pageSize) - 1) / int64(pageSize)
}

// POST /api/v1/courses/{slug}/chapters/{chapterSlug}/view（无认证）
func (s *Server) chapterView(c *gin.Context) {
	chapter, valid := s.chapterOrAbort(c)
	if !valid {
		return
	}
	// 只自增 view_count：UpdateColumn 不触发 GORM 的 UpdatedAt 自动更新。
	if err := s.db.Model(&chapter).UpdateColumn("view_count", gorm.Expr("view_count + 1")).Error; err != nil {
		s.internalError(c, err)
		return
	}
	var updated model.Chapter
	if err := s.db.Select("view_count").First(&updated, chapter.ID).Error; err != nil {
		s.internalError(c, err)
		return
	}
	ok(c, gin.H{"viewCount": updated.ViewCount})
}

// chapterLikeCount 统计某章节的点赞数。
func (s *Server) chapterLikeCount(courseSlug, chapterSlug string) (int64, error) {
	var n int64
	err := s.db.Model(&model.ChapterLike{}).
		Where("course_slug = ? AND chapter_slug = ?", courseSlug, chapterSlug).
		Count(&n).Error
	return n, err
}

// GET /api/v1/courses/{slug}/chapters/{chapterSlug}/stats（可选 Bearer）
func (s *Server) chapterStats(c *gin.Context) {
	chapter, valid := s.chapterOrAbort(c)
	if !valid {
		return
	}
	courseSlug := c.Param("slug")
	likeCount, err := s.chapterLikeCount(courseSlug, chapter.Slug)
	if err != nil {
		s.internalError(c, err)
		return
	}
	var commentCount int64
	if err := s.db.Model(&model.ChapterComment{}).
		Where("course_slug = ? AND chapter_slug = ?", courseSlug, chapter.Slug).
		Count(&commentCount).Error; err != nil {
		s.internalError(c, err)
		return
	}
	liked := false
	if userID := currentUserID(c); userID != 0 {
		var n int64
		if err := s.db.Model(&model.ChapterLike{}).
			Where("user_id = ? AND course_slug = ? AND chapter_slug = ?", userID, courseSlug, chapter.Slug).
			Count(&n).Error; err != nil {
			s.internalError(c, err)
			return
		}
		liked = n > 0
	}
	ok(c, gin.H{
		"viewCount":    chapter.ViewCount,
		"likeCount":    likeCount,
		"commentCount": commentCount,
		"liked":        liked,
	})
}

// POST /api/v1/courses/{slug}/chapters/{chapterSlug}/like（Bearer，幂等）
func (s *Server) likeChapter(c *gin.Context) {
	chapter, valid := s.chapterOrAbort(c)
	if !valid {
		return
	}
	like := model.ChapterLike{
		UserID:      currentUserID(c),
		CourseSlug:  c.Param("slug"),
		ChapterSlug: chapter.Slug,
	}
	// (user, course, chapter) 三列联合唯一：已点赞时冲突忽略，幂等返回当前状态。
	if err := s.db.Clauses(clause.OnConflict{DoNothing: true}).Create(&like).Error; err != nil {
		s.internalError(c, err)
		return
	}
	n, err := s.chapterLikeCount(like.CourseSlug, like.ChapterSlug)
	if err != nil {
		s.internalError(c, err)
		return
	}
	ok(c, gin.H{"liked": true, "likeCount": n})
}

// DELETE /api/v1/courses/{slug}/chapters/{chapterSlug}/like（Bearer，幂等）
func (s *Server) unlikeChapter(c *gin.Context) {
	chapter, valid := s.chapterOrAbort(c)
	if !valid {
		return
	}
	res := s.db.Where("user_id = ? AND course_slug = ? AND chapter_slug = ?",
		currentUserID(c), c.Param("slug"), chapter.Slug).
		Delete(&model.ChapterLike{})
	if res.Error != nil {
		s.internalError(c, res.Error)
		return
	}
	n, err := s.chapterLikeCount(c.Param("slug"), chapter.Slug)
	if err != nil {
		s.internalError(c, err)
		return
	}
	ok(c, gin.H{"liked": false, "likeCount": n})
}

// GET /api/v1/courses/{slug}/chapters/{chapterSlug}/comments（无认证，分页）
func (s *Server) listChapterComments(c *gin.Context) {
	chapter, valid := s.chapterOrAbort(c)
	if !valid {
		return
	}
	courseSlug := c.Param("slug")
	page, pageSize := pageParams(c)
	var total int64
	if err := s.db.Model(&model.ChapterComment{}).
		Where("course_slug = ? AND chapter_slug = ?", courseSlug, chapter.Slug).
		Count(&total).Error; err != nil {
		s.internalError(c, err)
		return
	}
	var rows []struct {
		ID        uint
		UserID    uint
		Username  *string
		Avatar    *string
		Content   string
		CreatedAt time.Time
	}
	err := s.db.Table("chapter_comments").
		Select("chapter_comments.id, chapter_comments.user_id, users.username, users.avatar, "+
			"chapter_comments.content, chapter_comments.created_at").
		Joins("LEFT JOIN users ON users.id = chapter_comments.user_id").
		Where("chapter_comments.course_slug = ? AND chapter_comments.chapter_slug = ?",
			courseSlug, chapter.Slug).
		Order("chapter_comments.created_at DESC, chapter_comments.id DESC").
		Limit(pageSize).Offset((page - 1) * pageSize).
		Scan(&rows).Error
	if err != nil {
		s.internalError(c, err)
		return
	}
	items := make([]commentItem, 0, len(rows))
	for _, row := range rows {
		username := deletedUsername
		if row.Username != nil && *row.Username != "" {
			username = *row.Username
		}
		avatar := ""
		if row.Avatar != nil {
			avatar = *row.Avatar
		}
		items = append(items, commentItem{
			ID:        row.ID,
			UserID:    row.UserID,
			Username:  username,
			Avatar:    avatar,
			Content:   row.Content,
			CreatedAt: row.CreatedAt.UTC().Format(time.RFC3339),
		})
	}
	ok(c, gin.H{
		"comments":  items,
		"total":     total,
		"page":      page,
		"pageSize":  pageSize,
		"pageCount": pageCount(total, pageSize),
	})
}

// POST /api/v1/courses/{slug}/chapters/{chapterSlug}/comments（Bearer）
func (s *Server) createChapterComment(c *gin.Context) {
	chapter, valid := s.chapterOrAbort(c)
	if !valid {
		return
	}
	var in struct {
		Content string `json:"content"`
	}
	if !bindUserJSON(c, &in) {
		return
	}
	content := strings.TrimSpace(in.Content)
	if n := len([]rune(content)); n < 1 || n > 1000 {
		fail(c, http.StatusBadRequest, "COMMENT_INVALID_INPUT", "content must be 1-1000 characters after trimming")
		return
	}
	userID := currentUserID(c)
	if s.tooFastComment(userID) {
		fail(c, http.StatusTooManyRequests, "COMMENT_TOO_FAST", "commenting too fast, retry in 10s")
		return
	}
	var user model.User
	err := s.db.First(&user, userID).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		fail(c, http.StatusUnauthorized, "AUTH_UNAUTHORIZED", "user not found")
		return
	}
	if err != nil {
		s.internalError(c, err)
		return
	}
	comment := model.ChapterComment{
		UserID:      userID,
		CourseSlug:  c.Param("slug"),
		ChapterSlug: chapter.Slug,
		Content:     content,
	}
	if err := s.db.Create(&comment).Error; err != nil {
		s.internalError(c, err)
		return
	}
	created(c, gin.H{"comment": commentItem{
		ID:        comment.ID,
		UserID:    comment.UserID,
		Username:  user.Username,
		Avatar:    user.Avatar,
		Content:   comment.Content,
		CreatedAt: comment.CreatedAt.UTC().Format(time.RFC3339),
	}})
}

// findComment 按路径 id 查评论；id 非数字或不存在时已写 404 响应。
func (s *Server) findComment(c *gin.Context) (model.ChapterComment, bool) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || id == 0 {
		fail(c, http.StatusNotFound, "NOT_FOUND", "comment not found")
		return model.ChapterComment{}, false
	}
	var comment model.ChapterComment
	if err := s.db.First(&comment, uint(id)).Error; err != nil {
		s.notFoundOrInternal(c, err, "comment not found")
		return comment, false
	}
	return comment, true
}

// DELETE /api/v1/comments/{id}（Bearer，仅作者本人）
func (s *Server) deleteComment(c *gin.Context) {
	comment, found := s.findComment(c)
	if !found {
		return
	}
	if comment.UserID != currentUserID(c) {
		fail(c, http.StatusForbidden, "COMMENT_FORBIDDEN", "only the author can delete this comment")
		return
	}
	if err := s.db.Delete(&comment).Error; err != nil {
		s.internalError(c, err)
		return
	}
	ok(c, gin.H{"deleted": 1})
}

// GET /api/v1/admin/comments?courseSlug=&page=&pageSize=（X-Admin-Token）
func (s *Server) adminListComments(c *gin.Context) {
	page, pageSize := pageParams(c)
	courseSlug := c.Query("courseSlug")
	// 联表均按唯一键关联（courses.slug、chapters.(course_id,slug)、users.id），
	// 不会放大行数；courseSlug 为空表示全部课程。
	newQuery := func() *gorm.DB {
		q := s.db.Table("chapter_comments").
			Joins("LEFT JOIN users ON users.id = chapter_comments.user_id").
			Joins("LEFT JOIN courses ON courses.slug = chapter_comments.course_slug").
			Joins("LEFT JOIN chapters ON chapters.course_id = courses.id AND chapters.slug = chapter_comments.chapter_slug")
		if courseSlug != "" {
			q = q.Where("chapter_comments.course_slug = ?", courseSlug)
		}
		return q
	}
	var total int64
	if err := newQuery().Count(&total).Error; err != nil {
		s.internalError(c, err)
		return
	}
	var rows []struct {
		ID           uint
		UserID       uint
		Username     *string
		CourseSlug   string
		CourseTitle  *string
		ChapterSlug  string
		ChapterTitle *string
		Content      string
		CreatedAt    time.Time
	}
	err := newQuery().
		Select("chapter_comments.id, chapter_comments.user_id, users.username, " +
			"chapter_comments.course_slug, courses.title AS course_title, chapter_comments.chapter_slug, " +
			"chapters.title AS chapter_title, chapter_comments.content, chapter_comments.created_at").
		Order("chapter_comments.created_at DESC, chapter_comments.id DESC").
		Limit(pageSize).Offset((page - 1) * pageSize).
		Scan(&rows).Error
	if err != nil {
		s.internalError(c, err)
		return
	}
	items := make([]adminCommentItem, 0, len(rows))
	for _, row := range rows {
		username := deletedUsername
		if row.Username != nil && *row.Username != "" {
			username = *row.Username
		}
		courseTitle := deletedCourseTitle
		if row.CourseTitle != nil && *row.CourseTitle != "" {
			courseTitle = *row.CourseTitle
		}
		chapterTitle := deletedChapterTitle
		if row.ChapterTitle != nil && *row.ChapterTitle != "" {
			chapterTitle = *row.ChapterTitle
		}
		items = append(items, adminCommentItem{
			ID:           row.ID,
			UserID:       row.UserID,
			Username:     username,
			CourseSlug:   row.CourseSlug,
			CourseTitle:  courseTitle,
			ChapterSlug:  row.ChapterSlug,
			ChapterTitle: chapterTitle,
			Content:      row.Content,
			CreatedAt:    row.CreatedAt.UTC().Format(time.RFC3339),
		})
	}
	ok(c, gin.H{
		"comments":  items,
		"total":     total,
		"page":      page,
		"pageSize":  pageSize,
		"pageCount": pageCount(total, pageSize),
	})
}

// DELETE /api/v1/admin/comments/{id}（X-Admin-Token，可删任意评论）
func (s *Server) adminDeleteComment(c *gin.Context) {
	comment, found := s.findComment(c)
	if !found {
		return
	}
	if err := s.db.Delete(&comment).Error; err != nil {
		s.internalError(c, err)
		return
	}
	ok(c, gin.H{"deleted": 1})
}
