package api

// 用户认证接口：注册 / 登录 / 当前用户信息，以及受保护接口共用的
// Bearer JWT 中间件。
//
// JWT：HS256；密钥读环境变量 AUTH_SECRET，未设置时使用开发默认值
// "dev-auth-secret"（NewRouter 启动时打日志提醒）；有效期 30 天；
// claims：sub（用户 id）、username、iat、exp。

import (
	"errors"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"code-tutorials/backend/internal/model"
)

// defaultAuthSecret AUTH_SECRET 未设置时使用的开发默认密钥。
const defaultAuthSecret = "dev-auth-secret"

// tokenTTL JWT 有效期：30 天。
const tokenTTL = 30 * 24 * time.Hour

// ctxUserID userAuth 成功后写入 gin context 的用户 id 键。
const ctxUserID = "userID"

// authSecret 返回 JWT 签名密钥：环境变量 AUTH_SECRET 优先，未设置为默认值。
func authSecret() string {
	if v := os.Getenv("AUTH_SECRET"); v != "" {
		return v
	}
	return defaultAuthSecret
}

// newAuthToken 为用户签发 HS256 JWT（sub=user id, username, iat, exp）。
func newAuthToken(user model.User) (string, error) {
	now := time.Now()
	claims := jwt.MapClaims{
		"sub":      strconv.FormatUint(uint64(user.ID), 10),
		"username": user.Username,
		"iat":      now.Unix(),
		"exp":      now.Add(tokenTTL).Unix(),
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(authSecret()))
}

// parseBearerUserID 校验并解析 JWT 字符串，返回用户 id；任何一步失败返回 false。
func parseBearerUserID(tokenString string) (uint, bool) {
	token, err := jwt.Parse(tokenString, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return []byte(authSecret()), nil
	})
	if err != nil || !token.Valid {
		return 0, false
	}
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return 0, false
	}
	sub, _ := claims["sub"].(string)
	userID, err := strconv.ParseUint(sub, 10, 64)
	if err != nil || userID == 0 {
		return 0, false
	}
	return uint(userID), true
}

// userAuth 校验 Authorization: Bearer <token>；失败一律 401 AUTH_UNAUTHORIZED，
// 成功把 userID（uint）写入 context。
func userAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		const prefix = "Bearer "
		if !strings.HasPrefix(header, prefix) {
			fail(c, http.StatusUnauthorized, "AUTH_UNAUTHORIZED", "missing bearer token")
			c.Abort()
			return
		}
		userID, ok := parseBearerUserID(strings.TrimPrefix(header, prefix))
		if !ok {
			fail(c, http.StatusUnauthorized, "AUTH_UNAUTHORIZED", "invalid or expired token")
			c.Abort()
			return
		}
		c.Set(ctxUserID, userID)
		c.Next()
	}
}

// optionalUserAuth 可选 Bearer：有合法 token 则把 userID 写入 context，
// 缺失或无效 token 一律放行（匿名），handler 用 currentUserID==0 判定匿名。
func optionalUserAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		const prefix = "Bearer "
		if strings.HasPrefix(header, prefix) {
			if userID, ok := parseBearerUserID(strings.TrimPrefix(header, prefix)); ok {
				c.Set(ctxUserID, userID)
			}
		}
		c.Next()
	}
}

// currentUserID 从 context 取 userAuth 写入的用户 id。
func currentUserID(c *gin.Context) uint {
	id, _ := c.Get(ctxUserID)
	userID, _ := id.(uint)
	return userID
}

// credentialsInput 注册/登录共用请求体。
type credentialsInput struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

// validCredentials 校验用户名 3-32 字节、密码 6-64 字节。
func validCredentials(username, password string) bool {
	return len(username) >= 3 && len(username) <= 32 &&
		len(password) >= 6 && len(password) <= 64
}

// bindUserJSON 解析用户端（auth/records）请求体，失败返回 false 并已写
// 400 AUTH_INVALID_INPUT 响应。
func bindUserJSON(c *gin.Context, in interface{}) bool {
	if err := c.ShouldBindJSON(in); err != nil {
		fail(c, http.StatusBadRequest, "AUTH_INVALID_INPUT", "invalid request body")
		return false
	}
	return true
}

// userPayload 用户公开字段（不含密码哈希），时间 RFC3339；avatar 为头像相对
// URL（如 "/avatars/3-ab12cd34.jpg"），未设置时为空串。
func userPayload(user model.User) gin.H {
	return gin.H{
		"id":        user.ID,
		"username":  user.Username,
		"avatar":    user.Avatar,
		"createdAt": user.CreatedAt.UTC().Format(time.RFC3339),
	}
}

// POST /api/v1/auth/register
func (s *Server) register(c *gin.Context) {
	var in credentialsInput
	if !bindUserJSON(c, &in) {
		return
	}
	if !validCredentials(in.Username, in.Password) {
		fail(c, http.StatusBadRequest, "AUTH_INVALID_INPUT",
			"username must be 3-32 bytes and password must be 6-64 bytes")
		return
	}
	var count int64
	if err := s.db.Model(&model.User{}).Where("username = ?", in.Username).Count(&count).Error; err != nil {
		s.internalError(c, err)
		return
	}
	if count > 0 {
		fail(c, http.StatusConflict, "AUTH_USERNAME_TAKEN", "username already exists")
		return
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(in.Password), bcrypt.DefaultCost)
	if err != nil {
		s.internalError(c, err)
		return
	}
	user := model.User{Username: in.Username, PasswordHash: string(hash)}
	if err := s.db.Create(&user).Error; err != nil {
		s.internalError(c, err)
		return
	}
	token, err := newAuthToken(user)
	if err != nil {
		s.internalError(c, err)
		return
	}
	created(c, gin.H{"token": token, "user": userPayload(user)})
}

// POST /api/v1/auth/login
func (s *Server) login(c *gin.Context) {
	var in credentialsInput
	if !bindUserJSON(c, &in) {
		return
	}
	if !validCredentials(in.Username, in.Password) {
		fail(c, http.StatusBadRequest, "AUTH_INVALID_INPUT",
			"username must be 3-32 bytes and password must be 6-64 bytes")
		return
	}
	var user model.User
	err := s.db.Where("username = ?", in.Username).First(&user).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		fail(c, http.StatusUnauthorized, "AUTH_INVALID_CREDENTIALS", "invalid username or password")
		return
	}
	if err != nil {
		s.internalError(c, err)
		return
	}
	if bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(in.Password)) != nil {
		fail(c, http.StatusUnauthorized, "AUTH_INVALID_CREDENTIALS", "invalid username or password")
		return
	}
	token, err := newAuthToken(user)
	if err != nil {
		s.internalError(c, err)
		return
	}
	ok(c, gin.H{"token": token, "user": userPayload(user)})
}

// GET /api/v1/auth/me（Bearer）
func (s *Server) me(c *gin.Context) {
	var user model.User
	err := s.db.First(&user, currentUserID(c)).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		fail(c, http.StatusUnauthorized, "AUTH_UNAUTHORIZED", "user not found")
		return
	}
	if err != nil {
		s.internalError(c, err)
		return
	}
	ok(c, gin.H{"user": userPayload(user)})
}
