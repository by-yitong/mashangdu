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
