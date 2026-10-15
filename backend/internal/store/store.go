// Package store 负责 SQLite 数据库的打开、迁移与示例数据播种。
package store

import (
	"embed"
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

var seedData = []seedCourse{
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

// Open 创建数据库文件（含父目录）、执行迁移，并在 courses 表为空时播种示例课程。
func Open(path string) (*gorm.DB, error) {
	if dir := filepath.Dir(path); dir != "" && dir != "." {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return nil, fmt.Errorf("create database directory: %w", err)
		}
	}
	db, err := gorm.Open(sqlite.Open(path), &gorm.Config{
		NowFunc: func() time.Time { return time.Now().UTC() },
		Logger:  logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		return nil, fmt.Errorf("open sqlite database: %w", err)
	}
	if err := db.AutoMigrate(&model.Course{}, &model.Chapter{}); err != nil {
		return nil, fmt.Errorf("migrate schema: %w", err)
	}
	if err := seed(db); err != nil {
		return nil, fmt.Errorf("seed sample data: %w", err)
	}
	return db, nil
}

func seed(db *gorm.DB) error {
	var count int64
	if err := db.Model(&model.Course{}).Count(&count).Error; err != nil {
		return err
	}
	if count > 0 {
		return nil
	}
	return db.Transaction(func(tx *gorm.DB) error {
		for _, sc := range seedData {
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
