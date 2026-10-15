// Package api 组装 Gin 路由，实现 /api/v1 下的教程内容接口。
package api

import (
	"errors"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"code-tutorials/backend/internal/model"
)

// envelope 统一响应信封：{"code","message","data"}。
type envelope struct {
	Code    string      `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data"`
}

func ok(c *gin.Context, data interface{}) {
	c.JSON(http.StatusOK, envelope{Code: "OK", Message: "ok", Data: data})
}

func fail(c *gin.Context, status int, code, message string) {
	c.JSON(status, envelope{Code: code, Message: message, Data: nil})
}

// Server 持有所有 handler 共享的依赖。
type Server struct {
	db *gorm.DB
}

// adminDistCandidates 未显式指定托管目录时，自动探测后台静态目录的候选路径
// （相对进程工作目录，目录需已构建完成，含 index.html）。
var adminDistCandidates = []string{
	"admin/dist",         // 在 backend/ 目录启动（go run .）
	"backend/admin/dist", // 在仓库根目录启动
}

// NewRouter 构建 Gin 引擎：CORS、统一错误信封与全部 /api/v1 路由。
// 可选参数 adminDist 指定后台 SPA 静态目录（挂载到 /admin，未知路径回退
// index.html）；不传时按候选路径自动探测，目录不存在则不挂载、行为不变。
func NewRouter(db *gorm.DB, adminDist ...string) *gin.Engine {
	s := &Server{db: db}
	r := gin.New()
	r.Use(gin.Logger(), cors(), recovery())

	adminIndex := mountAdmin(r, adminDist)
	r.NoRoute(func(c *gin.Context) {
		if adminIndex != "" && isAdminPageRequest(c) {
			c.File(adminIndex)
			return
		}
		fail(c, http.StatusNotFound, "NOT_FOUND", "not found")
	})

	v1 := r.Group("/api/v1")
	v1.GET("/meta", s.meta)
	v1.GET("/courses", s.listCourses)
	v1.GET("/courses/:slug", s.getCourse)
	v1.GET("/courses/:slug/chapters/:chapterSlug", s.getChapter)

	admin := v1.Group("/admin", adminAuth())
	admin.POST("/courses", s.createCourse)
	admin.PUT("/courses/:slug", s.updateCourse)
	admin.DELETE("/courses/:slug", s.deleteCourse)
	admin.POST("/courses/:slug/chapters", s.createChapter)
	admin.PUT("/courses/:slug/chapters/:chapterSlug", s.updateChapter)
	admin.DELETE("/courses/:slug/chapters/:chapterSlug", s.deleteChapter)
	return r
}

// mountAdmin 若目录存在则挂载 /admin 静态目录，返回 index.html 路径（用作 SPA
// 回退）；目录不存在或未指定时返回空串、不挂载。candidates 为空时按默认候选探测。
func mountAdmin(r *gin.Engine, candidates []string) string {
	if len(candidates) == 0 {
		candidates = adminDistCandidates
	}
	dir := ""
	for _, cand := range candidates {
		if cand == "" {
			continue
		}
		if st, err := os.Stat(cand); err == nil && st.IsDir() {
			dir = cand
			break
		}
	}
	if dir == "" {
		return ""
	}
	r.Static("/admin", dir)
	return filepath.Join(dir, "index.html")
}

// isAdminPageRequest 判断是否为需要回退到后台 SPA index.html 的请求：
// /admin 前缀的 GET/HEAD（静态文件已由 r.Static 处理，此处只接未知路径）。
func isAdminPageRequest(c *gin.Context) bool {
	if c.Request.Method != http.MethodGet && c.Request.Method != http.MethodHead {
		return false
	}
	p := c.Request.URL.Path
	return p == "/admin" || strings.HasPrefix(p, "/admin/")
}

// cors 开发期放开所有来源；允许管理端需要的写方法与 X-Admin-Token 头。
func cors() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Accept, X-Admin-Token")
		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}

// recovery 保证 panic 也返回统一信封（HTTP 500 / INTERNAL）。
func recovery() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if err := recover(); err != nil {
				fail(c, http.StatusInternalServerError, "INTERNAL", "internal error")
			}
		}()
		c.Next()
	}
}

func (s *Server) internalError(c *gin.Context, err error) {
	fail(c, http.StatusInternalServerError, "INTERNAL", "internal error")
}

func (s *Server) notFoundOrInternal(c *gin.Context, err error, message string) {
	if errors.Is(err, gorm.ErrRecordNotFound) {
		fail(c, http.StatusNotFound, "NOT_FOUND", message)
		return
	}
	s.internalError(c, err)
}

// GET /api/v1/meta
func (s *Server) meta(c *gin.Context) {
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
	ok(c, gin.H{
		"content_version": latest.UTC().Format(time.RFC3339),
		"course_count":    len(courses),
	})
}

type courseItem struct {
	Slug         string `json:"slug"`
	Title        string `json:"title"`
	Summary      string `json:"summary"`
	Language     string `json:"language"`
	Color        string `json:"color"`
	ChapterCount int    `json:"chapter_count"`
	UpdatedAt    string `json:"updated_at"`
}

// GET /api/v1/courses
func (s *Server) listCourses(c *gin.Context) {
	var courses []model.Course
	if err := s.db.Order("sort_order ASC, id ASC").Find(&courses).Error; err != nil {
		s.internalError(c, err)
		return
	}

	var counts []struct {
		CourseID uint
		Cnt      int
	}
	if err := s.db.Model(&model.Chapter{}).
		Select("course_id, COUNT(*) AS cnt").
		Group("course_id").
		Scan(&counts).Error; err != nil {
		s.internalError(c, err)
		return
	}
	countBy := make(map[uint]int, len(counts))
	for _, row := range counts {
		countBy[row.CourseID] = row.Cnt
	}

	items := make([]courseItem, 0, len(courses))
	for _, course := range courses {
		items = append(items, courseItem{
			Slug:         course.Slug,
			Title:        course.Title,
			Summary:      course.Summary,
			Language:     course.Language,
			Color:        course.Color,
			ChapterCount: countBy[course.ID],
			UpdatedAt:    course.UpdatedAt.UTC().Format(time.RFC3339),
		})
	}
	ok(c, items)
}

type chapterBrief struct {
	Slug  string `json:"slug"`
	Title string `json:"title"`
	Order int    `json:"order"`
}

// coursePayload 组装课程对象（GET /courses/:slug 与管理端共用结构）。
func coursePayload(course model.Course, chapters []chapterBrief) gin.H {
	return gin.H{
		"slug":       course.Slug,
		"title":      course.Title,
		"summary":    course.Summary,
		"language":   course.Language,
		"color":      course.Color,
		"updated_at": course.UpdatedAt.UTC().Format(time.RFC3339),
		"chapters":   chapters,
	}
}

// GET /api/v1/courses/:slug
func (s *Server) getCourse(c *gin.Context) {
	var course model.Course
	if err := s.db.Where("slug = ?", c.Param("slug")).First(&course).Error; err != nil {
		s.notFoundOrInternal(c, err, "course not found")
		return
	}
	briefs, err := s.chapterBriefs(course.ID)
	if err != nil {
		s.internalError(c, err)
		return
	}
	ok(c, coursePayload(course, briefs))
}

// chapterBriefs 查询某课程下的章节目录（按 sort_order 升序，不含正文）。
func (s *Server) chapterBriefs(courseID uint) ([]chapterBrief, error) {
	var chapters []model.Chapter
	if err := s.db.Where("course_id = ?", courseID).
		Order("sort_order ASC, id ASC").
		Find(&chapters).Error; err != nil {
		return nil, err
	}
	briefs := make([]chapterBrief, 0, len(chapters))
	for _, chapter := range chapters {
		briefs = append(briefs, chapterBrief{
			Slug:  chapter.Slug,
			Title: chapter.Title,
			Order: chapter.SortOrder,
		})
	}
	return briefs, nil
}

type chapterDetail struct {
	Slug       string `json:"slug"`
	CourseSlug string `json:"course_slug"`
	Title      string `json:"title"`
	Order      int    `json:"order"`
	ContentMD  string `json:"content_md"`
	UpdatedAt  string `json:"updated_at"`
}

// GET /api/v1/courses/:slug/chapters/:chapterSlug
func (s *Server) getChapter(c *gin.Context) {
	var course model.Course
	if err := s.db.Where("slug = ?", c.Param("slug")).First(&course).Error; err != nil {
		s.notFoundOrInternal(c, err, "course not found")
		return
	}
	var chapter model.Chapter
	if err := s.db.Where("course_id = ? AND slug = ?", course.ID, c.Param("chapterSlug")).
		First(&chapter).Error; err != nil {
		s.notFoundOrInternal(c, err, "chapter not found")
		return
	}
	ok(c, chapterDetail{
		Slug:       chapter.Slug,
		CourseSlug: course.Slug,
		Title:      chapter.Title,
		Order:      chapter.SortOrder,
		ContentMD:  chapter.ContentMD,
		UpdatedAt:  chapter.UpdatedAt.UTC().Format(time.RFC3339),
	})
}
