package api

// 管理端接口：/api/v1/admin 下的课程与章节 CRUD，供 React 后台调用。
//
// 鉴权：请求头 X-Admin-Token 必须等于环境变量 ADMIN_TOKEN；
// ADMIN_TOKEN 未设置或为空时整个管理端禁用（一律 403）。

import (
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"code-tutorials/backend/internal/model"
)

// adminTokenHeader 管理端鉴权请求头。
const adminTokenHeader = "X-Admin-Token"

// defaultCourseColor 课程 color 未提供时的默认值。
const defaultCourseColor = "#14B8A6"

// colorPattern 课程 color 的合法格式：#RRGGBB。
var colorPattern = regexp.MustCompile(`^#[0-9A-Fa-f]{6}$`)

// adminAuth 校验 X-Admin-Token。
func adminAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		want := os.Getenv("ADMIN_TOKEN")
		if want == "" {
			fail(c, http.StatusForbidden, "FORBIDDEN", "admin disabled: ADMIN_TOKEN not set")
			c.Abort()
			return
		}
		if c.GetHeader(adminTokenHeader) != want {
			fail(c, http.StatusForbidden, "FORBIDDEN", "invalid admin token")
			c.Abort()
			return
		}
		c.Next()
	}
}

// courseInput 创建/更新课程的请求体（更新时 slug 与 path 一致、以 path 为准）。
type courseInput struct {
	Slug      string `json:"slug"`
	Title     string `json:"title"`
	Summary   string `json:"summary"`
	Language  string `json:"language"`
	Color     string `json:"color"`
	SortOrder *int   `json:"sort_order"`
}

// chapterInput 创建/更新章节的请求体（更新时 slug 以 path 为准）。
type chapterInput struct {
	Slug      string  `json:"slug"`
	Title     string  `json:"title"`
	ContentMD *string `json:"content_md"`
	SortOrder *int    `json:"sort_order"`
}

// bindAdminJSON 解析请求体，失败返回 false 并已写 400 响应。
func bindAdminJSON(c *gin.Context, in interface{}) bool {
	if err := c.ShouldBindJSON(in); err != nil {
		fail(c, http.StatusBadRequest, "BAD_REQUEST", "invalid request body")
		return false
	}
	return true
}

// validateCourseCreate 校验创建课程的入参（slug 必填），返回规范化后的 color；
// 失败时已写 400 响应。
func validateCourseCreate(c *gin.Context, in *courseInput) (string, bool) {
	in.Slug = strings.TrimSpace(in.Slug)
	if in.Slug == "" {
		fail(c, http.StatusBadRequest, "BAD_REQUEST", "slug is required")
		return "", false
	}
	return validateCourseUpdate(c, in)
}

// validateCourseUpdate 校验更新课程的入参（slug 以 path 为准，不校验 body 中的
// slug），返回规范化后的 color；失败时已写 400 响应。
func validateCourseUpdate(c *gin.Context, in *courseInput) (string, bool) {
	if strings.TrimSpace(in.Title) == "" {
		fail(c, http.StatusBadRequest, "BAD_REQUEST", "title is required")
		return "", false
	}
	color := in.Color
	if color == "" {
		color = defaultCourseColor
	} else if !colorPattern.MatchString(color) {
		fail(c, http.StatusBadRequest, "BAD_REQUEST", "invalid color: want #RRGGBB")
		return "", false
	}
	return color, true
}

// nextCourseSortOrder 返回课程表最大 sort_order + 1（空表为 1），用于缺省排最后。
func (s *Server) nextCourseSortOrder() int {
	var maxOrder int
	if err := s.db.Model(&model.Course{}).
		Select("COALESCE(MAX(sort_order), 0)").Scan(&maxOrder).Error; err != nil {
		return 1
	}
	return maxOrder + 1
}

// nextChapterSortOrder 返回某课程下章节最大 sort_order + 1（无章节为 1）。
func (s *Server) nextChapterSortOrder(courseID uint) int {
	var maxOrder int
	if err := s.db.Model(&model.Chapter{}).Where("course_id = ?", courseID).
		Select("COALESCE(MAX(sort_order), 0)").Scan(&maxOrder).Error; err != nil {
		return 1
	}
	return maxOrder + 1
}

// findCourse 按 slug 查课程；不存在时已写 404 响应并返回 false。
func (s *Server) findCourse(c *gin.Context) (model.Course, bool) {
	var course model.Course
	if err := s.db.Where("slug = ?", c.Param("slug")).First(&course).Error; err != nil {
		s.notFoundOrInternal(c, err, "course not found")
		return course, false
	}
	return course, true
}

// findChapter 按 (course_id, chapterSlug) 查章节；不存在时已写 404 响应并返回 false。
func (s *Server) findChapter(c *gin.Context, courseID uint) (model.Chapter, bool) {
	var chapter model.Chapter
	if err := s.db.Where("course_id = ? AND slug = ?", courseID, c.Param("chapterSlug")).
		First(&chapter).Error; err != nil {
		s.notFoundOrInternal(c, err, "chapter not found")
		return chapter, false
	}
	return chapter, true
}

// POST /api/v1/admin/courses
func (s *Server) createCourse(c *gin.Context) {
	var in courseInput
	if !bindAdminJSON(c, &in) {
		return
	}
	color, valid := validateCourseCreate(c, &in)
	if !valid {
		return
	}
	var count int64
	if err := s.db.Model(&model.Course{}).Where("slug = ?", in.Slug).Count(&count).Error; err != nil {
		s.internalError(c, err)
		return
	}
	if count > 0 {
		fail(c, http.StatusBadRequest, "BAD_REQUEST", "course slug already exists")
		return
	}
	sortOrder := in.SortOrder
	if sortOrder == nil {
		n := s.nextCourseSortOrder()
		sortOrder = &n
	}
	course := model.Course{
		Slug:      in.Slug,
		Title:     in.Title,
		Summary:   in.Summary,
		Language:  in.Language,
		Color:     color,
		SortOrder: *sortOrder,
	}
	if err := s.db.Create(&course).Error; err != nil {
		s.internalError(c, err)
		return
	}
	ok(c, coursePayload(course, []chapterBrief{}))
}

// PUT /api/v1/admin/courses/{slug}
func (s *Server) updateCourse(c *gin.Context) {
	course, found := s.findCourse(c)
	if !found {
		return
	}
	var in courseInput
	if !bindAdminJSON(c, &in) {
		return
	}
	// 更新时以 path 中的 slug 为准，body 中的 slug 忽略（slug 不可改）。
	color, valid := validateCourseUpdate(c, &in)
	if !valid {
		return
	}
	sortOrder := course.SortOrder
	if in.SortOrder != nil {
		sortOrder = *in.SortOrder
	}
	if err := s.db.Model(&course).Updates(map[string]interface{}{
		"title":      in.Title,
		"summary":    in.Summary,
		"language":   in.Language,
		"color":      color,
		"sort_order": sortOrder,
	}).Error; err != nil {
		s.internalError(c, err)
		return
	}
	var updated model.Course
	if err := s.db.First(&updated, course.ID).Error; err != nil {
		s.internalError(c, err)
		return
	}
	briefs, err := s.chapterBriefs(updated.ID)
	if err != nil {
		s.internalError(c, err)
		return
	}
	ok(c, coursePayload(updated, briefs))
}

// DELETE /api/v1/admin/courses/{slug}
func (s *Server) deleteCourse(c *gin.Context) {
	course, found := s.findCourse(c)
	if !found {
		return
	}
	err := s.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("course_id = ?", course.ID).Delete(&model.Chapter{}).Error; err != nil {
			return err
		}
		return tx.Delete(&course).Error
	})
	if err != nil {
		s.internalError(c, err)
		return
	}
	ok(c, gin.H{"deleted": true})
}

// chapterPayload 组装章节对象（管理端返回结构）。
func chapterPayload(chapter model.Chapter, courseSlug string) gin.H {
	return gin.H{
		"slug":        chapter.Slug,
		"course_slug": courseSlug,
		"title":       chapter.Title,
		"order":       chapter.SortOrder,
		"updated_at":  chapter.UpdatedAt.UTC().Format(time.RFC3339),
	}
}

// POST /api/v1/admin/courses/{slug}/chapters
func (s *Server) createChapter(c *gin.Context) {
	course, found := s.findCourse(c)
	if !found {
		return
	}
	var in chapterInput
	if !bindAdminJSON(c, &in) {
		return
	}
	if !validateChapterCreate(c, &in) {
		return
	}
	var count int64
	if err := s.db.Model(&model.Chapter{}).
		Where("course_id = ? AND slug = ?", course.ID, in.Slug).
		Count(&count).Error; err != nil {
		s.internalError(c, err)
		return
	}
	if count > 0 {
		fail(c, http.StatusBadRequest, "BAD_REQUEST", "chapter slug already exists")
		return
	}
	sortOrder := in.SortOrder
	if sortOrder == nil {
		n := s.nextChapterSortOrder(course.ID)
		sortOrder = &n
	}
	content := ""
	if in.ContentMD != nil {
		content = *in.ContentMD
	}
	chapter := model.Chapter{
		CourseID:  course.ID,
		Slug:      in.Slug,
		Title:     in.Title,
		ContentMD: content,
		SortOrder: *sortOrder,
	}
	if err := s.db.Create(&chapter).Error; err != nil {
		s.internalError(c, err)
		return
	}
	ok(c, chapterPayload(chapter, course.Slug))
}

// validateChapterCreate 校验创建章节的入参（slug 必填）；失败时已写 400 响应。
func validateChapterCreate(c *gin.Context, in *chapterInput) bool {
	in.Slug = strings.TrimSpace(in.Slug)
	if in.Slug == "" {
		fail(c, http.StatusBadRequest, "BAD_REQUEST", "slug is required")
		return false
	}
	return validateChapterUpdate(c, in)
}

// validateChapterUpdate 校验更新章节的入参（slug 以 path 为准）；失败时已写 400 响应。
func validateChapterUpdate(c *gin.Context, in *chapterInput) bool {
	if strings.TrimSpace(in.Title) == "" {
		fail(c, http.StatusBadRequest, "BAD_REQUEST", "title is required")
		return false
	}
	return true
}

// PUT /api/v1/admin/courses/{slug}/chapters/{chapterSlug}
func (s *Server) updateChapter(c *gin.Context) {
	course, found := s.findCourse(c)
	if !found {
		return
	}
	chapter, found := s.findChapter(c, course.ID)
	if !found {
		return
	}
	var in chapterInput
	if !bindAdminJSON(c, &in) {
		return
	}
	// 更新时以 path 中的 slug 为准，body 中的 slug 忽略（slug 不可改）。
	if !validateChapterUpdate(c, &in) {
		return
	}
	updates := map[string]interface{}{"title": in.Title}
	if in.ContentMD != nil {
		updates["content_md"] = *in.ContentMD
	}
	if in.SortOrder != nil {
		updates["sort_order"] = *in.SortOrder
	}
	if err := s.db.Model(&chapter).Updates(updates).Error; err != nil {
		s.internalError(c, err)
		return
	}
	var updated model.Chapter
	if err := s.db.First(&updated, chapter.ID).Error; err != nil {
		s.internalError(c, err)
		return
	}
	ok(c, chapterPayload(updated, course.Slug))
}

// DELETE /api/v1/admin/courses/{slug}/chapters/{chapterSlug}
func (s *Server) deleteChapter(c *gin.Context) {
	course, found := s.findCourse(c)
	if !found {
		return
	}
	chapter, found := s.findChapter(c, course.ID)
	if !found {
		return
	}
	if err := s.db.Delete(&chapter).Error; err != nil {
		s.internalError(c, err)
		return
	}
	ok(c, gin.H{"deleted": true})
}
