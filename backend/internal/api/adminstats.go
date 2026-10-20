package api

// 管理端概况统计：GET /api/v1/admin/stats（X-Admin-Token），供后台仪表盘
// 一屏展示各表计数、总阅读量、内容版本与最新动态。
//
// 计数均为整表 COUNT；totalViews 为 chapters.view_count 求和（空表为 0）；
// contentVersion 与 GET /meta 同语义（courses+chapters 两表最大 updated_at，
// 删除不会降低版本号）。三个动态列表最多 5 条，空时为 [] 而非 null。

import (
	"time"

	"github.com/gin-gonic/gin"

	"code-tutorials/backend/internal/model"
)

// topChapterItem 热门章节单条结构（联 courses 补课程标识与标题）。
type topChapterItem struct {
	CourseSlug   string `json:"courseSlug"`
	CourseTitle  string `json:"courseTitle"`
	ChapterSlug  string `json:"chapterSlug"`
	ChapterTitle string `json:"chapterTitle"`
	ViewCount    int64  `json:"viewCount"`
}

// recentCommentItem 最新评论单条结构（联 users/chapters，被删用户与被删章节
// 走 deletedUsername / deletedChapterTitle 兜底）。
type recentCommentItem struct {
	ID           uint   `json:"id"`
	UserID       uint   `json:"userId"`
	Username     string `json:"username"`
	CourseSlug   string `json:"courseSlug"`
	ChapterSlug  string `json:"chapterSlug"`
	ChapterTitle string `json:"chapterTitle"`
	Content      string `json:"content"`
	CreatedAt    string `json:"createdAt"`
}

// GET /api/v1/admin/stats
func (s *Server) adminStats(c *gin.Context) {
	var courseCount, chapterCount, userCount, commentCount, likeCount int64
	for _, item := range []struct {
		table interface{}
		dest  *int64
	}{
		{&model.Course{}, &courseCount},
		{&model.Chapter{}, &chapterCount},
		{&model.User{}, &userCount},
		{&model.ChapterComment{}, &commentCount},
		{&model.ChapterLike{}, &likeCount},
	} {
		if err := s.db.Model(item.table).Count(item.dest).Error; err != nil {
			s.internalError(c, err)
			return
		}
	}
	// totalViews = SUM(chapters.view_count)，空表 COALESCE 为 0。
	var totalViews int64
	if err := s.db.Model(&model.Chapter{}).
		Select("COALESCE(SUM(view_count), 0)").Scan(&totalViews).Error; err != nil {
		s.internalError(c, err)
		return
	}

	// contentVersion 与 GET /meta 同语义：两表存活行的最大 updated_at。
	var courses []model.Course
	if err := s.db.Select("updated_at").Find(&courses).Error; err != nil {
		s.internalError(c, err)
		return
	}
	var chapters []model.Chapter
	if err := s.db.Select("updated_at").Find(&chapters).Error; err != nil {
		s.internalError(c, err)
		return
	}
	var latest time.Time
	for _, course := range courses {
		if course.UpdatedAt.After(latest) {
			latest = course.UpdatedAt
		}
	}
	for _, chapter := range chapters {
		if chapter.UpdatedAt.After(latest) {
			latest = chapter.UpdatedAt
		}
	}

	// 热门章节：view_count > 0 按其降序前 5（id 降序兜底同量并列的确定性）。
	var topRows []struct {
		CourseSlug   string
		CourseTitle  string
		ChapterSlug  string
		ChapterTitle string
		ViewCount    int64
	}
	if err := s.db.Table("chapters").
		Select("courses.slug AS course_slug, courses.title AS course_title, "+
			"chapters.slug AS chapter_slug, chapters.title AS chapter_title, chapters.view_count").
		Joins("JOIN courses ON courses.id = chapters.course_id").
		Where("chapters.view_count > 0").
		Order("chapters.view_count DESC, chapters.id DESC").
		Limit(5).
		Scan(&topRows).Error; err != nil {
		s.internalError(c, err)
		return
	}
	topChapters := make([]topChapterItem, 0, len(topRows))
	for _, row := range topRows {
		topChapters = append(topChapters, topChapterItem{
			CourseSlug:   row.CourseSlug,
			CourseTitle:  row.CourseTitle,
			ChapterSlug:  row.ChapterSlug,
			ChapterTitle: row.ChapterTitle,
			ViewCount:    row.ViewCount,
		})
	}

	// 最新注册用户：created_at DESC, id DESC 前 5；公开字段复用 userPayload。
	var users []model.User
	if err := s.db.Order("created_at DESC, id DESC").Limit(5).Find(&users).Error; err != nil {
		s.internalError(c, err)
		return
	}
	recentUsers := make([]gin.H, 0, len(users))
	for _, user := range users {
		recentUsers = append(recentUsers, userPayload(user))
	}

	// 最新评论：created_at DESC, id DESC 前 5；联表均 LEFT JOIN（联键与
	// adminListComments 一致），用户/章节被删时兜底，课程被删不影响展示。
	var commentRows []struct {
		ID           uint
		UserID       uint
		Username     *string
		CourseSlug   string
		ChapterSlug  string
		ChapterTitle *string
		Content      string
		CreatedAt    time.Time
	}
	if err := s.db.Table("chapter_comments").
		Select("chapter_comments.id, chapter_comments.user_id, users.username, "+
			"chapter_comments.course_slug, chapter_comments.chapter_slug, "+
			"chapters.title AS chapter_title, chapter_comments.content, chapter_comments.created_at").
		Joins("LEFT JOIN users ON users.id = chapter_comments.user_id").
		Joins("LEFT JOIN courses ON courses.slug = chapter_comments.course_slug").
		Joins("LEFT JOIN chapters ON chapters.course_id = courses.id AND chapters.slug = chapter_comments.chapter_slug").
		Order("chapter_comments.created_at DESC, chapter_comments.id DESC").
		Limit(5).
		Scan(&commentRows).Error; err != nil {
		s.internalError(c, err)
		return
	}
	recentComments := make([]recentCommentItem, 0, len(commentRows))
	for _, row := range commentRows {
		username := deletedUsername
		if row.Username != nil && *row.Username != "" {
			username = *row.Username
		}
		chapterTitle := deletedChapterTitle
		if row.ChapterTitle != nil && *row.ChapterTitle != "" {
			chapterTitle = *row.ChapterTitle
		}
		recentComments = append(recentComments, recentCommentItem{
			ID:           row.ID,
			UserID:       row.UserID,
			Username:     username,
			CourseSlug:   row.CourseSlug,
			ChapterSlug:  row.ChapterSlug,
			ChapterTitle: chapterTitle,
			Content:      row.Content,
			CreatedAt:    row.CreatedAt.UTC().Format(time.RFC3339),
		})
	}

	ok(c, gin.H{
		"courseCount":    courseCount,
		"chapterCount":   chapterCount,
		"totalViews":     totalViews,
		"userCount":      userCount,
		"commentCount":   commentCount,
		"likeCount":      likeCount,
		"contentVersion": latest.UTC().Format(time.RFC3339),
		"topChapters":    topChapters,
		"recentUsers":    recentUsers,
		"recentComments": recentComments,
	})
}
