// Package api 组装 Gin 路由，实现 /api/v1 下的教程内容接口。
package api

import (
	"errors"
	"io/fs"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"code-tutorials/backend/internal/model"
	"code-tutorials/backend/internal/store"
	"code-tutorials/backend/web"
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

// created 与 ok 相同信封，但状态码为 201（注册、创建 App 版本等）。
func created(c *gin.Context, data interface{}) {
	c.JSON(http.StatusCreated, envelope{Code: "OK", Message: "ok", Data: data})
}

func fail(c *gin.Context, status int, code, message string) {
	c.JSON(status, envelope{Code: code, Message: message, Data: nil})
}

// Server 持有所有 handler 共享的依赖；lastCommentAt 为评论频控（同一用户
// 两次评论最小间隔，进程内 map + 互斥锁，重启清零可接受）。
// seedDir 为课程包落盘目录（courses.json 与章节 md，管理端导入接口写入）；
// imagesRoot 为教程图片根目录（/images 静态托管与导入接口共用）。
type Server struct {
	db            *gorm.DB
	seedDir       string
	imagesRoot    string
	commentMu     sync.Mutex
	lastCommentAt map[uint]time.Time
}

// imagesRoot 教程图片静态目录，相对进程工作目录（在 backend/ 下启动即
// backend/static/images）。目录可不存在，缺失时请求一律 404，启动不强行创建；
// 声明为 var 仅供测试注入临时目录。
var imagesRoot = "static/images"

// avatarsRoot 用户头像静态目录（backend/data/avatars），行为与 imagesRoot 一致；
// 上传接口（POST /api/v1/me/avatar）保存文件时会 MkdirAll 创建。
var avatarsRoot = "data/avatars"

// NewRouter 构建 Gin 引擎：CORS、统一错误信封与全部 /api/v1 路由。
// seedDir 默认取 store.ResolveSeedDir()（磁盘 seeddata 探测），imagesRoot
// 默认取包级变量（测试可整体替换后再构造）。
// 后台 SPA（/admin）由编译期嵌入的 web.DistFS 托管（构建流程：先在仓库根
// admin/ 执行 npm run build，产物拷贝到 backend/web/dist/ 后再 go build），
// 静态文件 200；/admin 前缀下未知的 GET/HEAD 路径回退 index.html。
// 另将 GET /images/*filepath 挂载到 imagesRoot（教程图片静态托管，无需认证）。
func NewRouter(db *gorm.DB) *gin.Engine {
	return NewRouterWithDirs(db, store.ResolveSeedDir(), imagesRoot)
}

// NewRouterWithDirs 与 NewRouter 相同，但显式指定课程包目录（seedDir）与
// 教程图片根目录（imgRoot），空串回退各自默认值；供测试注入临时目录，
// 生产调用点仍走 NewRouter。
func NewRouterWithDirs(db *gorm.DB, seedDir, imgRoot string) *gin.Engine {
	if seedDir == "" {
		seedDir = store.ResolveSeedDir()
	}
	if imgRoot == "" {
		imgRoot = imagesRoot
	}
	s := &Server{db: db, seedDir: seedDir, imagesRoot: imgRoot, lastCommentAt: make(map[uint]time.Time)}
	r := gin.New()
	r.Use(gin.Logger(), cors(), recovery())

	if os.Getenv("AUTH_SECRET") == "" {
		log.Printf("AUTH_SECRET not set; using default development secret (set AUTH_SECRET in production)")
	}

	mountAdmin(r)

	// GET /images/*filepath 教程图片静态托管（离线下载配套，无需认证）。
	// 目录不存在时不强行创建：文件缺失或目录未落盘时 gin 静态处理器回退
	// NoRoute，统一返回 404 JSON 信封（.. 穿越由 http.Dir 清洗、同样 404）；
	// 目录后续落盘后无需重启即可生效。
	r.Static("/images", s.imagesRoot)

	// GET /avatars/*filepath 用户头像静态托管（无需认证），行为与 /images 一致：
	// 目录缺失/文件不存在统一 404 信封；目录由上传接口按需创建。
	r.Static("/avatars", avatarsRoot)

	r.NoRoute(func(c *gin.Context) {
		if isAdminPageRequest(c) {
			serveAdminIndex(c)
			return
		}
		fail(c, http.StatusNotFound, "NOT_FOUND", "not found")
	})

	v1 := r.Group("/api/v1")
	v1.GET("/meta", s.meta)
	v1.GET("/courses", s.listCourses)
	v1.GET("/courses/:slug", s.getCourse)
	v1.GET("/courses/:slug/chapters/:chapterSlug", s.getChapter)

	// 用户认证：注册/登录无需 token；me 需要 Bearer。
	v1.POST("/auth/register", s.register)
	v1.POST("/auth/login", s.login)
	v1.GET("/auth/me", userAuth(), s.me)

	// 观看记录：全部需要 Bearer。
	v1.PUT("/records", userAuth(), s.upsertRecord)
	v1.GET("/records", userAuth(), s.listRecords)
	v1.DELETE("/records", userAuth(), s.clearRecords)
	v1.DELETE("/records/:courseSlug/:chapterSlug", userAuth(), s.deleteRecord)

	// 用户头像：上传需要 Bearer；GET /avatars/*filepath 静态托管见上方。
	v1.POST("/me/avatar", userAuth(), s.uploadAvatar)

	// 章节互动：阅读量/评论列表无认证；stats 支持可选 Bearer（liked 字段）；
	// 点赞与发评论需要 Bearer。
	v1.POST("/courses/:slug/chapters/:chapterSlug/view", s.chapterView)
	v1.GET("/courses/:slug/chapters/:chapterSlug/stats", optionalUserAuth(), s.chapterStats)
	v1.POST("/courses/:slug/chapters/:chapterSlug/like", userAuth(), s.likeChapter)
	v1.DELETE("/courses/:slug/chapters/:chapterSlug/like", userAuth(), s.unlikeChapter)
	v1.GET("/courses/:slug/chapters/:chapterSlug/comments", s.listChapterComments)
	v1.POST("/courses/:slug/chapters/:chapterSlug/comments", userAuth(), s.createChapterComment)
	v1.DELETE("/comments/:id", userAuth(), s.deleteComment)

	// App 版本：latest 供客户端无认证检查更新。
	v1.GET("/app/latest", s.appLatest)

	admin := v1.Group("/admin", adminAuth())
	admin.POST("/courses", s.createCourse)
	admin.POST("/courses/import", s.importCourses)
	admin.PUT("/courses/:slug", s.updateCourse)
	admin.DELETE("/courses/:slug", s.deleteCourse)
	admin.POST("/courses/:slug/chapters", s.createChapter)
	admin.PUT("/courses/:slug/chapters/:chapterSlug", s.updateChapter)
	admin.DELETE("/courses/:slug/chapters/:chapterSlug", s.deleteChapter)
	admin.GET("/app-versions", s.listAppVersions)
	admin.POST("/app-versions", s.createAppVersion)
	admin.PUT("/app-versions/:id", s.updateAppVersion)
	admin.DELETE("/app-versions/:id", s.deleteAppVersion)
	admin.GET("/comments", s.adminListComments)
	admin.DELETE("/comments/:id", s.adminDeleteComment)
	return r
}

// mountAdmin 把编译期嵌入的后台静态产物（web.DistFS，dist 位于嵌入 FS 根）
// 挂载到 /admin：真实文件直接 200；/admin 前缀下不存在的 GET/HEAD 路径由
// gin 静态处理器落入 NoRoute、回退 index.html（SPA）。OnlyFilesFS 包装保持
// 与原磁盘托管一致的行为（禁目录列表）。
func mountAdmin(r *gin.Engine) {
	dist, err := fs.Sub(web.DistFS, "dist")
	if err != nil {
		// dist 由 go:embed 编译期保证存在，此分支不可达。
		panic("api: embedded admin dist: " + err.Error())
	}
	r.StaticFS("/admin", &gin.OnlyFilesFS{FileSystem: http.FS(dist)})
}

// serveAdminIndex 以嵌入的 dist/index.html 响应 SPA 回退请求（内容为编译
// 期常量，直接整体写出）。读取失败不可达（go:embed 保证文件存在），此时
// 返回与其他未知路径一致的 404 信封。
func serveAdminIndex(c *gin.Context) {
	index, err := web.DistFS.ReadFile("dist/index.html")
	if err != nil {
		fail(c, http.StatusNotFound, "NOT_FOUND", "not found")
		return
	}
	c.Data(http.StatusOK, "text/html; charset=utf-8", index)
}

// isAdminPageRequest 判断是否为需要回退到后台 SPA index.html 的请求：
// /admin 前缀的 GET/HEAD（静态文件已由 r.StaticFS 处理，此处只接未知路径）。
func isAdminPageRequest(c *gin.Context) bool {
	if c.Request.Method != http.MethodGet && c.Request.Method != http.MethodHead {
		return false
	}
	p := c.Request.URL.Path
	return p == "/admin" || strings.HasPrefix(p, "/admin/")
}

// cors 开发期放开所有来源；允许写方法与 X-Admin-Token / Authorization 头。
func cors() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Accept, X-Admin-Token, Authorization")
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
