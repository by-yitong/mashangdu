// Package model 定义教程内容的 GORM 数据模型。
package model

import "time"

// Course 一门教程课程。
type Course struct {
	ID        uint   `gorm:"primaryKey"`
	Slug      string `gorm:"size:128;not null;uniqueIndex"`
	Title     string `gorm:"size:256;not null"`
	Summary   string `gorm:"size:1024;not null;default:''"`
	Language  string `gorm:"size:64;not null;default:''"`
	Color     string `gorm:"size:16;not null;default:''"`
	SortOrder int    `gorm:"not null;default:0"`
	CreatedAt time.Time
	UpdatedAt time.Time
}

// Chapter 课程下的一个章节，ContentMD 存 markdown 正文。
type Chapter struct {
	ID        uint   `gorm:"primaryKey"`
	CourseID  uint   `gorm:"not null;uniqueIndex:idx_chapters_course_slug,priority:1"`
	Slug      string `gorm:"size:128;not null;uniqueIndex:idx_chapters_course_slug,priority:2"`
	Title     string `gorm:"size:256;not null"`
	ContentMD string `gorm:"not null"`
	SortOrder int    `gorm:"not null;default:0"`
	CreatedAt time.Time
	UpdatedAt time.Time
}

// User App 端注册用户；密码仅存 bcrypt 哈希，永不出库。
type User struct {
	ID           uint   `gorm:"primaryKey"`
	Username     string `gorm:"size:32;not null;uniqueIndex"`
	PasswordHash string `gorm:"size:128;not null"`
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

// ReadingRecord 用户对某课程某章节的最近一次观看记录；(user_id, course_slug,
// chapter_slug) 三列联合唯一，重复观看按 upsert 更新 read_at。
type ReadingRecord struct {
	ID           uint      `gorm:"primaryKey"`
	UserID       uint      `gorm:"not null;index;uniqueIndex:idx_records_user_chapter,priority:1"`
	CourseSlug   string    `gorm:"size:128;not null;uniqueIndex:idx_records_user_chapter,priority:2"`
	ChapterSlug  string    `gorm:"size:128;not null;uniqueIndex:idx_records_user_chapter,priority:3"`
	ChapterTitle string    `gorm:"size:256;not null"`
	ReadAt       time.Time `gorm:"not null"`
}

// AppRelease App 安装包版本；version_code 全局唯一，latest 接口取 enabled 中最大者。
type AppRelease struct {
	ID          uint   `gorm:"primaryKey"`
	Version     string `gorm:"size:32;not null"`
	VersionCode int    `gorm:"not null;uniqueIndex"`
	Notes       string `gorm:"type:text;not null;default:''"`
	ApkURL      string `gorm:"column:apk_url;size:512;not null"`
	Force       bool   `gorm:"not null;default:false"`
	Enabled     bool   `gorm:"not null;default:true"`
	CreatedAt   time.Time
	UpdatedAt   time.Time
}
