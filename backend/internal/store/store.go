// Package store 负责 SQLite 数据库的打开、迁移与磁盘 seeddata 的播种。
package store

import (
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

// Open 创建数据库文件（含父目录）、执行迁移并播种内容，等价于 OpenSeed(path, "")。
func Open(path string) (*gorm.DB, error) {
	return OpenSeed(path, "")
}

// OpenSeed 打开数据库并播种内容；seedDir 显式指定 seeddata 目录（含 courses.json 与
// md 文件），为空串时按候选路径自动探测。
//
// 播种规则：课程内容是运行时数据，二进制不携带任何文章。只来自磁盘
// seeddata/courses.json（相对进程工作目录探测）或管理端导入接口写入的同一目录。
// 若 seeddata/courses.json 存在则按其 upsert（课程按 slug、章节按
// (course_id, slug) 存在则更新、不存在则创建，永不删除）；否则空库启动，
// 不播种任何内容。
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
	if err := db.AutoMigrate(&model.Course{}, &model.Chapter{}, &model.User{}, &model.ReadingRecord{},
		&model.AppRelease{}, &model.ChapterComment{}, &model.ChapterLike{}); err != nil {
		return nil, fmt.Errorf("migrate schema: %w", err)
	}
	if err := seed(db, seedDir); err != nil {
		return nil, fmt.Errorf("seed courses: %w", err)
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

// ResolveSeedDir 按候选路径（相对进程工作目录）探测 seeddata 目录并返回；
// 未找到任何候选时返回首选候选 internal/store/seeddata（目录可能尚不存在，
// 供管理端导入接口按需创建落盘），保证运行时数据目录位置确定。
func ResolveSeedDir() string {
	if dir, ok := resolveSeedDir(""); ok {
		return dir
	}
	return seedDirCandidates[0]
}

// seed 播种磁盘 seeddata/courses.json；课程内容是运行时数据，只来自磁盘
// seeddata/（相对进程工作目录探测）或管理端导入接口，二进制不携带任何文章，
// 找不到 courses.json 时直接空库启动，不播种任何内容。
func seed(db *gorm.DB, seedDir string) error {
	if dir, ok := resolveSeedDir(seedDir); ok {
		jsonPath := filepath.Join(dir, "courses.json")
		if fileExists(jsonPath) {
			return upsertFromCoursesJSON(db, dir, jsonPath)
		}
	}
	return nil
}

// UpsertCoursesJSON 按 dir/courses.json（路径由 jsonPath 显式指定）upsert 课程
// 与章节进已打开的 db，供管理端导入接口在运行时调用，无需重启服务。
// 语义与启动播种一致：存在则更新（仅在内容有变化时写库），不存在则创建，
// 永不删除。
func UpsertCoursesJSON(db *gorm.DB, dir, jsonPath string) error {
	return upsertFromCoursesJSON(db, dir, jsonPath)
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
