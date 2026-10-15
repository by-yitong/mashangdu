// Package store 负责 SQLite 数据库的打开、迁移与示例数据播种。
package store

import (
	"embed"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"code-tutorials/backend/internal/model"
)

//go:embed seeddata
var seedFS embed.FS

// seedDirCandidates 自动探测 seeddata 目录时的候选路径（相对进程工作目录）。
var seedDirCandidates = []string{
	"internal/store/seeddata",         // 在 backend/ 目录启动（go run .）
	"seeddata",                        // 在 internal/store 包目录下运行测试
	"../store/seeddata",               // 在 internal/api 等包目录下运行测试
	"backend/internal/store/seeddata", // 在仓库根目录启动
}

// coursesJSONFile 是 seeddata/courses.json 的结构（schema 已冻结）。
// file 字段为相对 seeddata 目录的 markdown 文件名，读取其全文作为章节正文。
type coursesJSONFile struct {
	Courses []coursesJSONCourse `json:"courses"`
}

type coursesJSONCourse struct {
	Slug      string               `json:"slug"`
	Title     string               `json:"title"`
	Summary   string               `json:"summary"`
	Language  string               `json:"language"`
	Color     string               `json:"color"`
	SortOrder int                  `json:"sort_order"`
	Chapters  []coursesJSONChapter `json:"chapters"`
}

type coursesJSONChapter struct {
	Slug      string `json:"slug"`
	Title     string `json:"title"`
	SortOrder int    `json:"sort_order"`
	File      string `json:"file"`
}

type seedChapter struct {
	Slug  string
	Title string
	Order int
	File  string
}

type seedCourse struct {
	Slug      string
	Title     string
	Summary   string
	Language  string
	Color     string
	SortOrder int
	Chapters  []seedChapter
}

// seedHardcoded 无 courses.json 时的兜底种子（5 章）。
var seedHardcodedData = []seedCourse{
	{
		Slug:      "go-basics",
		Title:     "Go 语言入门",
		Summary:   "从零开始学 Go：写出第一个程序、认识变量与类型，再到 goroutine 并发入门，跑通 Go 学习的第一段路。",
		Language:  "Go",
		Color:     "#14B8A6",
		SortOrder: 1,
		Chapters: []seedChapter{
			{Slug: "hello-world", Title: "Hello World", Order: 1, File: "go-hello-world.md"},
			{Slug: "variables", Title: "变量与基本类型", Order: 2, File: "go-variables.md"},
			{Slug: "goroutine", Title: "goroutine 并发入门", Order: 3, File: "go-goroutine.md"},
		},
	},
	{
		Slug:      "python-basics",
		Title:     "Python 基础",
		Summary:   "面向零基础读者的 Python 入门：装好环境、玩转 REPL，掌握变量与控制流，迈出编程第一步。",
		Language:  "Python",
		Color:     "#4C6BB0",
		SortOrder: 2,
		Chapters: []seedChapter{
			{Slug: "install-repl", Title: "安装与 REPL", Order: 1, File: "python-install-repl.md"},
			{Slug: "variables-controlflow", Title: "变量与控制流", Order: 2, File: "python-variables-controlflow.md"},
		},
	},
}

// Open 创建数据库文件（含父目录）、执行迁移并播种内容，等价于 OpenSeed(path, "")。
func Open(path string) (*gorm.DB, error) {
	return OpenSeed(path, "")
}

// OpenSeed 打开数据库并播种内容；seedDir 显式指定 seeddata 目录（含 courses.json 与
// md 文件），为空串时按候选路径自动探测。
//
// 播种规则：若 seeddata/courses.json 存在则按其 upsert（课程按 slug、章节按
// (course_id, slug) 存在则更新、不存在则创建，永不删除）；否则在 courses 表为空时
// 播种内置示例数据（5 章）。
func OpenSeed(dbPath, seedDir string) (*gorm.DB, error) {
	if dir := filepath.Dir(dbPath); dir != "" && dir != "." {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return nil, fmt.Errorf("create database directory: %w", err)
		}
	}
	db, err := gorm.Open(sqlite.Open(dbPath), &gorm.Config{
		NowFunc: func() time.Time { return time.Now().UTC() },
		Logger:  logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		return nil, fmt.Errorf("open sqlite database: %w", err)
	}
	if err := db.AutoMigrate(&model.Course{}, &model.Chapter{}); err != nil {
		return nil, fmt.Errorf("migrate schema: %w", err)
	}
	if err := seed(db, seedDir); err != nil {
		return nil, fmt.Errorf("seed sample data: %w", err)
	}
	return db, nil
}

// resolveSeedDir 确定 seeddata 目录：显式指定时校验存在，否则按候选路径探测。
func resolveSeedDir(explicit string) (string, bool) {
	if explicit != "" {
		if st, err := os.Stat(explicit); err == nil && st.IsDir() {
			return explicit, true
		}
		return "", false
	}
	for _, cand := range seedDirCandidates {
		if st, err := os.Stat(cand); err == nil && st.IsDir() {
			return cand, true
		}
	}
	return "", false
}

func seed(db *gorm.DB, seedDir string) error {
	if dir, ok := resolveSeedDir(seedDir); ok {
		jsonPath := filepath.Join(dir, "courses.json")
		if fileExists(jsonPath) {
			return upsertFromCoursesJSON(db, dir, jsonPath)
		}
	}
	return seedFallback(db)
}

// seedFallback 原有行为：courses 表为空时播种内置示例数据。
func seedFallback(db *gorm.DB) error {
	var count int64
	if err := db.Model(&model.Course{}).Count(&count).Error; err != nil {
		return err
	}
	if count > 0 {
		return nil
	}
	return db.Transaction(func(tx *gorm.DB) error {
		for _, sc := range seedHardcodedData {
			course := model.Course{
				Slug:      sc.Slug,
				Title:     sc.Title,
				Summary:   sc.Summary,
				Language:  sc.Language,
				Color:     sc.Color,
				SortOrder: sc.SortOrder,
			}
			if err := tx.Create(&course).Error; err != nil {
				return err
			}
			for _, sch := range sc.Chapters {
				content, err := seedFS.ReadFile("seeddata/" + sch.File)
				if err != nil {
					return err
				}
				chapter := model.Chapter{
					CourseID:  course.ID,
					Slug:      sch.Slug,
					Title:     sch.Title,
					ContentMD: string(content),
					SortOrder: sch.Order,
				}
				if err := tx.Create(&chapter).Error; err != nil {
					return err
				}
			}
		}
		return nil
	})
}

// upsertFromCoursesJSON 按 courses.json upsert 课程与章节：存在则更新（仅在内容
// 有变化时写库，避免无谓抬高 updated_at / content_version），不存在则创建，永不删除。
func upsertFromCoursesJSON(db *gorm.DB, seedDir, jsonPath string) error {
	raw, err := os.ReadFile(jsonPath)
	if err != nil {
		return fmt.Errorf("read %s: %w", jsonPath, err)
	}
	var payload coursesJSONFile
	if err := json.Unmarshal(raw, &payload); err != nil {
		return fmt.Errorf("parse %s: %w", jsonPath, err)
	}
	return db.Transaction(func(tx *gorm.DB) error {
		for _, jc := range payload.Courses {
			courseID, err := upsertCourse(tx, jc)
			if err != nil {
				return err
			}
			for _, jch := range jc.Chapters {
				content, err := os.ReadFile(filepath.Join(seedDir, jch.File))
				if err != nil {
					return fmt.Errorf("read chapter file %s (referenced by %s): %w", jch.File, jsonPath, err)
				}
				if err := upsertChapter(tx, courseID, jch, content); err != nil {
					return err
				}
			}
		}
		return nil
	})
}

func upsertCourse(tx *gorm.DB, jc coursesJSONCourse) (uint, error) {
	color := jc.Color
	if color == "" {
		color = "#14B8A6"
	}
	var course model.Course
	err := tx.Where("slug = ?", jc.Slug).First(&course).Error
	switch {
	case errors.Is(err, gorm.ErrRecordNotFound):
		course = model.Course{
			Slug:      jc.Slug,
			Title:     jc.Title,
			Summary:   jc.Summary,
			Language:  jc.Language,
			Color:     color,
			SortOrder: jc.SortOrder,
		}
		if err := tx.Create(&course).Error; err != nil {
			return 0, err
		}
		return course.ID, nil
	case err != nil:
		return 0, err
	}
	if course.Title == jc.Title && course.Summary == jc.Summary &&
		course.Language == jc.Language && course.Color == color && course.SortOrder == jc.SortOrder {
		return course.ID, nil
	}
	if err := tx.Model(&course).Updates(map[string]interface{}{
		"title":      jc.Title,
		"summary":    jc.Summary,
		"language":   jc.Language,
		"color":      color,
		"sort_order": jc.SortOrder,
	}).Error; err != nil {
		return 0, err
	}
	return course.ID, nil
}

func upsertChapter(tx *gorm.DB, courseID uint, jch coursesJSONChapter, content []byte) error {
	var chapter model.Chapter
	err := tx.Where("course_id = ? AND slug = ?", courseID, jch.Slug).First(&chapter).Error
	switch {
	case errors.Is(err, gorm.ErrRecordNotFound):
		chapter = model.Chapter{
			CourseID:  courseID,
			Slug:      jch.Slug,
			Title:     jch.Title,
			ContentMD: string(content),
			SortOrder: jch.SortOrder,
		}
		return tx.Create(&chapter).Error
	case err != nil:
		return err
	}
	if chapter.Title == jch.Title && chapter.SortOrder == jch.SortOrder && chapter.ContentMD == string(content) {
		return nil
	}
	return tx.Model(&chapter).Updates(map[string]interface{}{
		"title":      jch.Title,
		"content_md": string(content),
		"sort_order": jch.SortOrder,
	}).Error
}

func fileExists(path string) bool {
	st, err := os.Stat(path)
	return err == nil && !st.IsDir()
}
