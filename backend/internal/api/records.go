package api

// 观看记录接口（全部需要 Bearer 认证）：PUT 记录/更新某章节的阅读，GET 拉取
// 最近 200 条（按 read_at 降序），DELETE 删单条或清空。
//
// 课程/章节合法性校验走 courses + chapters 联表：courseSlug 必须存在、
// chapterSlug 必须属于该课程，否则 404 NOT_FOUND。

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"code-tutorials/backend/internal/model"
)

// recordsLimit GET /records 返回的最大条数。
const recordsLimit = 200

// deletedCourseTitle 课程已被删除时观看记录里展示的课程名兜底。
const deletedCourseTitle = "(已删除课程)"

// recordInput PUT /records 请求体。
type recordInput struct {
	CourseSlug   string `json:"courseSlug"`
	ChapterSlug  string `json:"chapterSlug"`
	ChapterTitle string `json:"chapterTitle"`
}

// PUT /api/v1/records（Bearer）
func (s *Server) upsertRecord(c *gin.Context) {
	var in recordInput
	if !bindUserJSON(c, &in) {
		return
	}
	// 联表校验：课程存在且章节属于该课程；章节标题留作兜底。
	var chapter model.Chapter
	err := s.db.Joins("JOIN courses ON courses.id = chapters.course_id").
		Where("courses.slug = ? AND chapters.slug = ?", in.CourseSlug, in.ChapterSlug).
		First(&chapter).Error
	if err == gorm.ErrRecordNotFound {
		fail(c, http.StatusNotFound, "NOT_FOUND", "course or chapter not found")
		return
	}
	if err != nil {
		s.internalError(c, err)
		return
	}
	title := in.ChapterTitle
	if title == "" {
		title = chapter.Title
	}
	now := time.Now().UTC()
	record := model.ReadingRecord{
		UserID:       currentUserID(c),
		CourseSlug:   in.CourseSlug,
		ChapterSlug:  in.ChapterSlug,
		ChapterTitle: title,
		ReadAt:       now,
	}
	err = s.db.Clauses(clause.OnConflict{
		Columns: []clause.Column{
			{Name: "user_id"}, {Name: "course_slug"}, {Name: "chapter_slug"},
		},
		DoUpdates: clause.Assignments(map[string]interface{}{
			"chapter_title": title,
			"read_at":       now,
		}),
	}).Create(&record).Error
	if err != nil {
		s.internalError(c, err)
		return
	}
	ok(c, gin.H{"ok": true})
}

// recordItem GET /records 返回的单条记录。
type recordItem struct {
	CourseSlug   string `json:"courseSlug"`
	CourseTitle  string `json:"courseTitle"`
	ChapterSlug  string `json:"chapterSlug"`
	ChapterTitle string `json:"chapterTitle"`
	ReadAt       string `json:"readAt"`
}

// GET /api/v1/records（Bearer）：按 readAt 降序，最多 200 条；课程被删时
// courseTitle 兜底为 "(已删除课程)"。
func (s *Server) listRecords(c *gin.Context) {
	var rows []struct {
		CourseSlug   string
		CourseTitle  *string
		ChapterSlug  string
		ChapterTitle string
		ReadAt       time.Time
	}
	err := s.db.Table("reading_records").
		Select("reading_records.course_slug, courses.title AS course_title, "+
			"reading_records.chapter_slug, reading_records.chapter_title, reading_records.read_at").
		Joins("LEFT JOIN courses ON courses.slug = reading_records.course_slug").
		Where("reading_records.user_id = ?", currentUserID(c)).
		Order("reading_records.read_at DESC, reading_records.id DESC").
		Limit(recordsLimit).
		Scan(&rows).Error
	if err != nil {
		s.internalError(c, err)
		return
	}
	items := make([]recordItem, 0, len(rows))
	for _, row := range rows {
		courseTitle := deletedCourseTitle
		if row.CourseTitle != nil && *row.CourseTitle != "" {
			courseTitle = *row.CourseTitle
		}
		items = append(items, recordItem{
			CourseSlug:   row.CourseSlug,
			CourseTitle:  courseTitle,
			ChapterSlug:  row.ChapterSlug,
			ChapterTitle: row.ChapterTitle,
			ReadAt:       row.ReadAt.UTC().Format(time.RFC3339),
		})
	}
	ok(c, gin.H{"records": items})
}

// DELETE /api/v1/records/{courseSlug}/{chapterSlug}（Bearer）：删单条。
func (s *Server) deleteRecord(c *gin.Context) {
	res := s.db.Where("user_id = ? AND course_slug = ? AND chapter_slug = ?",
		currentUserID(c), c.Param("courseSlug"), c.Param("chapterSlug")).
		Delete(&model.ReadingRecord{})
	if res.Error != nil {
		s.internalError(c, res.Error)
		return
	}
	ok(c, gin.H{"deleted": res.RowsAffected})
}

// DELETE /api/v1/records（Bearer）：清空该用户全部记录。
func (s *Server) clearRecords(c *gin.Context) {
	res := s.db.Where("user_id = ?", currentUserID(c)).Delete(&model.ReadingRecord{})
	if res.Error != nil {
		s.internalError(c, res.Error)
		return
	}
	ok(c, gin.H{"deleted": res.RowsAffected})
}
