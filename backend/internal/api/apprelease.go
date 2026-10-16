package api

// App 版本接口：GET /app/latest 供客户端检查更新（无认证）；管理端
// /admin/app-versions 提供版本 CRUD（X-Admin-Token 鉴权，错误码与现有管理端
// 风格一致：入参不合法 400 BAD_REQUEST，versionCode 重复 409 VERSION_CONFLICT）。

import (
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"code-tutorials/backend/internal/model"
)

// appVersionInput 管理端创建/更新版本请求体；force/enabled 用指针区分
// "未提供"（更新时保持原值）与 false。
type appVersionInput struct {
	Version     string `json:"version"`
	VersionCode int    `json:"versionCode"`
	Notes       string `json:"notes"`
	ApkURL      string `json:"apkUrl"`
	Force       *bool  `json:"force"`
	Enabled     *bool  `json:"enabled"`
}

// appVersionPayload 管理端返回的完整版本对象。
func appVersionPayload(rel model.AppRelease) gin.H {
	return gin.H{
		"id":          rel.ID,
		"version":     rel.Version,
		"versionCode": rel.VersionCode,
		"notes":       rel.Notes,
		"apkUrl":      rel.ApkURL,
		"force":       rel.Force,
		"enabled":     rel.Enabled,
		"releasedAt":  rel.CreatedAt.UTC().Format(time.RFC3339),
	}
}

// GET /api/v1/app/latest（无认证）：enabled 中 version_code 最大的一条。
func (s *Server) appLatest(c *gin.Context) {
	var rel model.AppRelease
	err := s.db.Where("enabled = ?", true).
		Order("version_code DESC").First(&rel).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		fail(c, http.StatusNotFound, "NOT_FOUND", "app release not found")
		return
	}
	if err != nil {
		s.internalError(c, err)
		return
	}
	ok(c, gin.H{
		"version":     rel.Version,
		"versionCode": rel.VersionCode,
		"notes":       rel.Notes,
		"apkUrl":      rel.ApkURL,
		"force":       rel.Force,
		"releasedAt":  rel.CreatedAt.UTC().Format(time.RFC3339),
	})
}

// validateAppVersion 校验创建/更新入参（version/apkUrl 非空、versionCode>0）；
// 失败时已写 400 响应。
func validateAppVersion(c *gin.Context, in *appVersionInput) bool {
	if strings.TrimSpace(in.Version) == "" {
		fail(c, http.StatusBadRequest, "BAD_REQUEST", "version is required")
		return false
	}
	if strings.TrimSpace(in.ApkURL) == "" {
		fail(c, http.StatusBadRequest, "BAD_REQUEST", "apkUrl is required")
		return false
	}
	if in.VersionCode <= 0 {
		fail(c, http.StatusBadRequest, "BAD_REQUEST", "versionCode must be a positive integer")
		return false
	}
	return true
}

// versionCodeTaken 检查 version_code 是否已被其他记录占用（excludeID=0 表示
// 全表检查，用于创建）；查询出错时保守返回 true（创建路径随后会撞唯一索引
// 返回 500，属于异常场景）。
func (s *Server) versionCodeTaken(versionCode, excludeID uint) bool {
	var count int64
	if err := s.db.Model(&model.AppRelease{}).
		Where("version_code = ? AND id <> ?", versionCode, excludeID).
		Count(&count).Error; err != nil {
		return true
	}
	return count > 0
}

// findAppVersion 按路径 id 查版本；不存在或 id 非数字时已写 404 响应。
func (s *Server) findAppVersion(c *gin.Context) (model.AppRelease, bool) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || id == 0 {
		fail(c, http.StatusNotFound, "NOT_FOUND", "app version not found")
		return model.AppRelease{}, false
	}
	var rel model.AppRelease
	if err := s.db.First(&rel, uint(id)).Error; err != nil {
		s.notFoundOrInternal(c, err, "app version not found")
		return rel, false
	}
	return rel, true
}

// GET /api/v1/admin/app-versions：按 versionCode 降序。
func (s *Server) listAppVersions(c *gin.Context) {
	var releases []model.AppRelease
	if err := s.db.Order("version_code DESC, id DESC").Find(&releases).Error; err != nil {
		s.internalError(c, err)
		return
	}
	items := make([]gin.H, 0, len(releases))
	for _, rel := range releases {
		items = append(items, appVersionPayload(rel))
	}
	ok(c, items)
}

// POST /api/v1/admin/app-versions：创建（默认 enabled=true）。
func (s *Server) createAppVersion(c *gin.Context) {
	var in appVersionInput
	if !bindAdminJSON(c, &in) {
		return
	}
	if !validateAppVersion(c, &in) {
		return
	}
	if s.versionCodeTaken(uint(in.VersionCode), 0) {
		fail(c, http.StatusConflict, "VERSION_CONFLICT", "versionCode already exists")
		return
	}
	force := in.Force != nil && *in.Force
	rel := model.AppRelease{
		Version:     in.Version,
		VersionCode: in.VersionCode,
		Notes:       in.Notes,
		ApkURL:      in.ApkURL,
		Force:       force,
		Enabled:     true,
	}
	if err := s.db.Create(&rel).Error; err != nil {
		s.internalError(c, err)
		return
	}
	created(c, appVersionPayload(rel))
}

// PUT /api/v1/admin/app-versions/{id}：更新全部字段；force/enabled 缺省保持原值。
func (s *Server) updateAppVersion(c *gin.Context) {
	rel, found := s.findAppVersion(c)
	if !found {
		return
	}
	var in appVersionInput
	if !bindAdminJSON(c, &in) {
		return
	}
	if !validateAppVersion(c, &in) {
		return
	}
	if s.versionCodeTaken(uint(in.VersionCode), rel.ID) {
		fail(c, http.StatusConflict, "VERSION_CONFLICT", "versionCode already exists")
		return
	}
	updates := map[string]interface{}{
		"version":      in.Version,
		"version_code": in.VersionCode,
		"notes":        in.Notes,
		"apk_url":      in.ApkURL,
	}
	if in.Force != nil {
		updates["force"] = *in.Force
	}
	if in.Enabled != nil {
		updates["enabled"] = *in.Enabled
	}
	if err := s.db.Model(&rel).Updates(updates).Error; err != nil {
		s.internalError(c, err)
		return
	}
	var updated model.AppRelease
	if err := s.db.First(&updated, rel.ID).Error; err != nil {
		s.internalError(c, err)
		return
	}
	ok(c, appVersionPayload(updated))
}

// DELETE /api/v1/admin/app-versions/{id}
func (s *Server) deleteAppVersion(c *gin.Context) {
	rel, found := s.findAppVersion(c)
	if !found {
		return
	}
	if err := s.db.Delete(&rel).Error; err != nil {
		s.internalError(c, err)
		return
	}
	ok(c, gin.H{"ok": true})
}
