package store_test

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"gorm.io/gorm"

	"code-tutorials/backend/internal/model"
	"code-tutorials/backend/internal/store"
)

// copyExampleSeed 把 courses.example.json 与其引用的 md 文件复制到临时目录，
// 组装出一个可用作 seedDir 的目录（不读写真实 courses.json）。
func copyExampleSeed(t *testing.T, dir string) string {
	t.Helper()
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatalf("mkdir seed dir: %v", err)
	}
	raw, err := os.ReadFile(filepath.Join("seeddata", "courses.example.json"))
	if err != nil {
		t.Fatalf("read courses.example.json: %v", err)
	}
	var payload struct {
		Courses []struct {
			Chapters []struct {
				File string `json:"file"`
			} `json:"chapters"`
		} `json:"courses"`
	}
	if err := json.Unmarshal(raw, &payload); err != nil {
		t.Fatalf("parse courses.example.json: %v", err)
	}
	if err := os.WriteFile(filepath.Join(dir, "courses.json"), raw, 0o644); err != nil {
		t.Fatalf("write courses.json: %v", err)
	}
	copied := map[string]bool{}
	for _, course := range payload.Courses {
		for _, chapter := range course.Chapters {
			if copied[chapter.File] {
				continue
			}
			copied[chapter.File] = true
			content, err := os.ReadFile(filepath.Join("seeddata", chapter.File))
			if err != nil {
				t.Fatalf("read seed md %s: %v", chapter.File, err)
			}
			if err := os.WriteFile(filepath.Join(dir, chapter.File), content, 0o644); err != nil {
				t.Fatalf("write seed md %s: %v", chapter.File, err)
			}
		}
	}
	return dir
}

func countRows(t *testing.T, db *gorm.DB, model interface{}) int64 {
	t.Helper()
	var count int64
	if err := db.Model(model).Count(&count).Error; err != nil {
		t.Fatalf("count rows: %v", err)
	}
	return count
}

// maxUpdatedAt 返回 courses 与 chapters 两表的最大 updated_at（即 content_version 语义）。
func maxUpdatedAt(t *testing.T, db *gorm.DB) time.Time {
	t.Helper()
	var latest time.Time
	for _, m := range []interface{}{&model.Course{}, &model.Chapter{}} {
		var rows []struct {
			UpdatedAt time.Time
		}
		if err := db.Model(m).Select("updated_at").Find(&rows).Error; err != nil {
			t.Fatalf("select updated_at: %v", err)
		}
		for _, row := range rows {
			if row.UpdatedAt.After(latest) {
				latest = row.UpdatedAt
			}
		}
	}
	return latest
}

func closeDB(db *gorm.DB) {
	if sqlDB, err := db.DB(); err == nil {
		_ = sqlDB.Close()
	}
}

func TestUpsertFromCoursesJSON(t *testing.T) {
	root := t.TempDir()
	dbPath := filepath.Join(root, "test.db")
	seedDir := copyExampleSeed(t, filepath.Join(root, "seed"))

	// 首次播种：2 门课程、5 章。
	db, err := store.OpenSeed(dbPath, seedDir)
	if err != nil {
		t.Fatalf("first OpenSeed: %v", err)
	}
	if got := countRows(t, db, &model.Course{}); got != 2 {
		t.Fatalf("course count = %d, want 2", got)
	}
	if got := countRows(t, db, &model.Chapter{}); got != 5 {
		t.Fatalf("chapter count = %d, want 5", got)
	}
	var goCourse model.Course
	if err := db.Where("slug = ?", "go-basics").First(&goCourse).Error; err != nil {
		t.Fatalf("load go-basics: %v", err)
	}
	if goCourse.Title != "Go 语言入门" || goCourse.Color != "#14B8A6" {
		t.Fatalf("go-basics = %+v", goCourse)
	}
	version1 := maxUpdatedAt(t, db)
	closeDB(db)

	// 二次打开（json 无变化）：upsert 不应触碰任何行，content_version 不变。
	db2, err := store.OpenSeed(dbPath, seedDir)
	if err != nil {
		t.Fatalf("second OpenSeed: %v", err)
	}
	version2 := maxUpdatedAt(t, db2)
	if !version1.Equal(version2) {
		t.Fatalf("content_version changed without data change: %v -> %v", version1, version2)
	}
	closeDB(db2)

	// 修改 json：更新 go-basics 标题、更新一个章节、去掉 python-basics。
	raw, err := os.ReadFile(filepath.Join(seedDir, "courses.json"))
	if err != nil {
		t.Fatalf("read courses.json: %v", err)
	}
	var payload map[string]interface{}
	if err := json.Unmarshal(raw, &payload); err != nil {
		t.Fatalf("parse courses.json: %v", err)
	}
	courses := payload["courses"].([]interface{})
	courses = courses[:1] // 去掉 python-basics，验证永不删除
	courses[0].(map[string]interface{})["title"] = "Go 入门（更新）"
	chapters := courses[0].(map[string]interface{})["chapters"].([]interface{})
	chapters[0].(map[string]interface{})["title"] = "Hello World（更新）"
	payload["courses"] = courses
	updated, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("marshal updated json: %v", err)
	}
	if err := os.WriteFile(filepath.Join(seedDir, "courses.json"), updated, 0o644); err != nil {
		t.Fatalf("write updated courses.json: %v", err)
	}

	db3, err := store.OpenSeed(dbPath, seedDir)
	if err != nil {
		t.Fatalf("third OpenSeed: %v", err)
	}
	defer closeDB(db3)
	var updatedCourse model.Course
	if err := db3.Where("slug = ?", "go-basics").First(&updatedCourse).Error; err != nil {
		t.Fatalf("load go-basics after update: %v", err)
	}
	if updatedCourse.Title != "Go 入门（更新）" {
		t.Fatalf("go-basics title = %q, want updated", updatedCourse.Title)
	}
	var pyCourse model.Course
	if err := db3.Where("slug = ?", "python-basics").First(&pyCourse).Error; err != nil {
		t.Fatalf("python-basics should never be deleted: %v", err)
	}
	var updatedChapter model.Chapter
	if err := db3.Where("course_id = ? AND slug = ?", updatedCourse.ID, "hello-world").
		First(&updatedChapter).Error; err != nil {
		t.Fatalf("load hello-world: %v", err)
	}
	if updatedChapter.Title != "Hello World（更新）" {
		t.Fatalf("hello-world title = %q, want updated", updatedChapter.Title)
	}
	if version3 := maxUpdatedAt(t, db3); !version3.After(version2) {
		t.Fatalf("content_version should advance after real change: %v -> %v", version2, version3)
	}
}

// TestSeedWithoutJSONStartsEmpty 无磁盘 courses.json 时直接空库启动：
// 二进制不再携带任何课程内容（embed 已移除），空 seeddata 目录不播种任何数据。
func TestSeedWithoutJSONStartsEmpty(t *testing.T) {
	db, err := store.OpenSeed(filepath.Join(t.TempDir(), "test.db"), t.TempDir())
	if err != nil {
		t.Fatalf("OpenSeed without courses.json: %v", err)
	}
	defer closeDB(db)
	if got := countRows(t, db, &model.Course{}); got != 0 {
		t.Fatalf("course count = %d, want 0 (empty start)", got)
	}
	if got := countRows(t, db, &model.Chapter{}); got != 0 {
		t.Fatalf("chapter count = %d, want 0 (empty start)", got)
	}
}

// TestResolveSeedDir 探测结果：找到存在的候选目录；全不存在时返回首选候选
// （可能尚不存在，供导入接口按需创建）。
func TestResolveSeedDir(t *testing.T) {
	if dir := store.ResolveSeedDir(); dir == "" {
		t.Fatal("ResolveSeedDir returned empty string")
	}
	// 测试工作目录为 internal/store，"seeddata" 候选必命中真实目录。
	if dir := store.ResolveSeedDir(); dir != "seeddata" {
		t.Fatalf("ResolveSeedDir in store package = %q, want seeddata", dir)
	}
}
