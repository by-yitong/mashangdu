package api

// 用户头像接口：POST /api/v1/me/avatar（Bearer，multipart/form-data 字段 file）
// 上传，GET /avatars/*filepath 静态托管（挂载见 api.go，无需认证）。
//
// 校验：文件必须存在、大小 ≤5MB（读内容前用 multipart header.Size 判断）、
// 魔数只允许 JPEG/PNG/WEBP；任一不满足返回 400 AVATAR_INVALID。
// 文件名 {userID}-{8位hex随机}.{jpg|png|webp}（crypto/rand），上传成功后删除
// 旧头像文件（存在且位于 avatarsRoot 内时）。

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"code-tutorials/backend/internal/model"
)

// avatarMaxBytes 头像文件大小上限：5MB。
const avatarMaxBytes = 5 << 20

// avatarMultipartMemory 解析 multipart 表单的内存上限：8MB（超出部分落临时文件，
// 随后仍会被 header.Size 的 5MB 校验拒绝）。
const avatarMultipartMemory = 8 << 20

// detectAvatarExt 魔数检测图片类型：JPEG(FF D8 FF)/PNG(89 50 4E 47)/
// WEBP(RIFF....WEBP)，返回扩展名与是否合法。
func detectAvatarExt(head []byte) (string, bool) {
	if len(head) >= 3 && head[0] == 0xFF && head[1] == 0xD8 && head[2] == 0xFF {
		return "jpg", true
	}
	if len(head) >= 4 && head[0] == 0x89 && head[1] == 0x50 && head[2] == 0x4E && head[3] == 0x47 {
		return "png", true
	}
	if len(head) >= 12 && string(head[0:4]) == "RIFF" && string(head[8:12]) == "WEBP" {
		return "webp", true
	}
	return "", false
}

// removeAvatarFile 删除旧头像文件：仅当 URL 为 /avatars/ 前缀且清洗后的相对
// 路径未越出 avatarsRoot 时才删；失败静默（残留文件不影响正确性）。
func removeAvatarFile(avatarURL string) {
	const prefix = "/avatars/"
	if !strings.HasPrefix(avatarURL, prefix) {
		return
	}
	clean := filepath.ToSlash(filepath.Clean(strings.TrimPrefix(avatarURL, prefix)))
	if clean == "." || clean == ".." || strings.HasPrefix(clean, "../") {
		return
	}
	_ = os.Remove(filepath.FromSlash(filepath.Join(avatarsRoot, clean)))
}

// POST /api/v1/me/avatar（Bearer，multipart/form-data，字段名 file）
func (s *Server) uploadAvatar(c *gin.Context) {
	if err := c.Request.ParseMultipartForm(avatarMultipartMemory); err != nil {
		fail(c, http.StatusBadRequest, "AVATAR_INVALID", "invalid multipart form")
		return
	}
	fileHeader, err := c.FormFile("file")
	if err != nil {
		fail(c, http.StatusBadRequest, "AVATAR_INVALID", "file field is required")
		return
	}
	if fileHeader.Size > avatarMaxBytes {
		fail(c, http.StatusBadRequest, "AVATAR_INVALID", "file exceeds 5MB limit")
		return
	}
	f, err := fileHeader.Open()
	if err != nil {
		fail(c, http.StatusBadRequest, "AVATAR_INVALID", "cannot read uploaded file")
		return
	}
	defer f.Close()
	raw := make([]byte, fileHeader.Size)
	if _, err := io.ReadFull(f, raw); err != nil {
		fail(c, http.StatusBadRequest, "AVATAR_INVALID", "cannot read uploaded file")
		return
	}
	ext, validImage := detectAvatarExt(raw)
	if !validImage {
		fail(c, http.StatusBadRequest, "AVATAR_INVALID", "only JPEG, PNG or WEBP images are allowed")
		return
	}

	var rnd [4]byte
	if _, err := rand.Read(rnd[:]); err != nil {
		s.internalError(c, err)
		return
	}
	name := fmt.Sprintf("%d-%s.%s", currentUserID(c), hex.EncodeToString(rnd[:]), ext)
	if err := os.MkdirAll(avatarsRoot, 0o755); err != nil {
		s.internalError(c, err)
		return
	}
	if err := os.WriteFile(filepath.Join(avatarsRoot, name), raw, 0o644); err != nil {
		s.internalError(c, err)
		return
	}

	var user model.User
	err = s.db.First(&user, currentUserID(c)).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		fail(c, http.StatusUnauthorized, "AUTH_UNAUTHORIZED", "user not found")
		return
	}
	if err != nil {
		s.internalError(c, err)
		return
	}
	oldAvatar := user.Avatar
	if err := s.db.Model(&user).Update("avatar", "/avatars/"+name).Error; err != nil {
		s.internalError(c, err)
		return
	}
	user.Avatar = "/avatars/" + name
	removeAvatarFile(oldAvatar)
	ok(c, gin.H{"user": userPayload(user)})
}
