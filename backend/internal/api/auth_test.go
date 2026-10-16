package api_test

// 用户认证接口测试：注册 / 登录 / me、入参校验、重复注册、错凭证、
// 密码不泄露。

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

// userDo 发起用户端请求；token 非空时带上 Authorization: Bearer 头。
func userDo(t *testing.T, r *gin.Engine, method, path, token string, body interface{}) (int, response) {
	t.Helper()
	var reader *bytes.Reader
	if body != nil {
		raw, err := json.Marshal(body)
		if err != nil {
			t.Fatalf("marshal request body: %v", err)
		}
		reader = bytes.NewReader(raw)
	} else {
		reader = bytes.NewReader(nil)
	}
	w := httptest.NewRecorder()
	req := httptest.NewRequest(method, path, reader)
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	r.ServeHTTP(w, req)
	var resp response
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response body %q: %v", w.Body.String(), err)
	}
	return w.Code, resp
}

// authData 注册/登录/me 响应的 data 结构。
type authData struct {
	Token string `json:"token"`
	User  struct {
		ID        uint   `json:"id"`
		Username  string `json:"username"`
		CreatedAt string `json:"createdAt"`
	} `json:"user"`
}

// registerUserAs 注册指定用户并断言 201，返回 (token, data)。
func registerUserAs(t *testing.T, r *gin.Engine, username, password string) (string, authData) {
	t.Helper()
	status, resp := userDo(t, r, http.MethodPost, "/api/v1/auth/register", "", map[string]string{
		"username": username,
		"password": password,
	})
	if status != http.StatusCreated || resp.Code != "OK" {
		t.Fatalf("register %q: status = %d code = %s, want 201 OK (body: %s)",
			username, status, resp.Code, resp.Data)
	}
	var data authData
	if err := json.Unmarshal(resp.Data, &data); err != nil {
		t.Fatalf("unmarshal register data %s: %v", resp.Data, err)
	}
	if data.Token == "" {
		t.Fatalf("register %q: token is empty", username)
	}
	return data.Token, data
}

// registerUser 注册默认用户 alice/secret123。
func registerUser(t *testing.T, r *gin.Engine) (string, authData) {
	t.Helper()
	return registerUserAs(t, r, "alice", "secret123")
}

func TestAuthRegisterLoginMe(t *testing.T) {
	r := newRouter(t)

	// 注册：201，token 与用户公开字段齐全，明文密码与哈希字段不出现在响应里。
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/register",
		bytes.NewReader([]byte(`{"username":"alice","password":"secret123"}`)))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("register: status = %d, want 201 (body: %s)", w.Code, w.Body.String())
	}
	body := w.Body.String()
	if strings.Contains(body, "secret123") || strings.Contains(strings.ToLower(body), "passwordhash") {
		t.Fatalf("register response leaks password: %s", body)
	}
	var envelopeResp response
	if err := json.Unmarshal(w.Body.Bytes(), &envelopeResp); err != nil {
		t.Fatalf("unmarshal register envelope: %v", err)
	}
	var data authData
	if err := json.Unmarshal(envelopeResp.Data, &data); err != nil {
		t.Fatalf("unmarshal register data %s: %v", envelopeResp.Data, err)
	}
	if data.Token == "" || data.User.ID == 0 || data.User.Username != "alice" {
		t.Fatalf("register data = %+v", data)
	}
	assertRFC3339(t, "register", "createdAt", data.User.CreatedAt)
	registerToken := data.Token

	// 登录：200，返回同构 data。
	status, resp := userDo(t, r, http.MethodPost, "/api/v1/auth/login", "", map[string]string{
		"username": "alice", "password": "secret123",
	})
	if status != http.StatusOK || resp.Code != "OK" {
		t.Fatalf("login: status = %d code = %s, want 200 OK", status, resp.Code)
	}
	var loginData authData
	if err := json.Unmarshal(resp.Data, &loginData); err != nil {
		t.Fatalf("unmarshal login data: %v", err)
	}
	if loginData.Token == "" || loginData.User.Username != "alice" || loginData.User.ID != data.User.ID {
		t.Fatalf("login data = %+v", loginData)
	}

	// me：带 token 200；未带 / 格式错 / 伪造签名 / 垃圾 token 均 401。
	status, resp = userDo(t, r, http.MethodGet, "/api/v1/auth/me", registerToken, nil)
	if status != http.StatusOK || resp.Code != "OK" {
		t.Fatalf("me with token: status = %d code = %s, want 200 OK", status, resp.Code)
	}
	var me struct {
		User struct {
			ID        uint   `json:"id"`
			Username  string `json:"username"`
			CreatedAt string `json:"createdAt"`
		} `json:"user"`
	}
	if err := json.Unmarshal(resp.Data, &me); err != nil {
		t.Fatalf("unmarshal me data: %v", err)
	}
	if me.User.Username != "alice" || me.User.ID != data.User.ID {
		t.Fatalf("me user = %+v, want alice #%d", me.User, data.User.ID)
	}
	assertRFC3339(t, "me", "createdAt", me.User.CreatedAt)

	w2 := httptest.NewRecorder()
	req2 := httptest.NewRequest(http.MethodGet, "/api/v1/auth/me", nil)
	r.ServeHTTP(w2, req2)
	if w2.Code != http.StatusUnauthorized {
		t.Fatalf("me without token: status = %d, want 401", w2.Code)
	}
	var resp2 response
	if err := json.Unmarshal(w2.Body.Bytes(), &resp2); err != nil || resp2.Code != "AUTH_UNAUTHORIZED" {
		t.Fatalf("me without token: code = %q err = %v, want AUTH_UNAUTHORIZED", resp2.Code, err)
	}

	// 非法 Authorization 头（非 Bearer 前缀）→ 401。
	w3 := httptest.NewRecorder()
	req3 := httptest.NewRequest(http.MethodGet, "/api/v1/auth/me", nil)
	req3.Header.Set("Authorization", "Token abc")
	r.ServeHTTP(w3, req3)
	if w3.Code != http.StatusUnauthorized {
		t.Fatalf("me with non-bearer header: status = %d, want 401", w3.Code)
	}

	// 用错误密钥签发的 token → 401（AUTH_SECRET 未设置，服务端用默认密钥）。
	now := time.Now()
	badToken, err := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"sub": "1", "username": "alice", "iat": now.Unix(), "exp": now.Add(time.Hour).Unix(),
	}).SignedString([]byte("wrong-secret"))
	if err != nil {
		t.Fatalf("sign bad token: %v", err)
	}
	if status, resp := userDo(t, r, http.MethodGet, "/api/v1/auth/me", badToken, nil); status != http.StatusUnauthorized || resp.Code != "AUTH_UNAUTHORIZED" {
		t.Fatalf("me with wrong-secret token: status = %d code = %s, want 401 AUTH_UNAUTHORIZED", status, resp.Code)
	}
	if status, resp := userDo(t, r, http.MethodGet, "/api/v1/auth/me", "garbage.token", nil); status != http.StatusUnauthorized || resp.Code != "AUTH_UNAUTHORIZED" {
		t.Fatalf("me with garbage token: status = %d code = %s, want 401 AUTH_UNAUTHORIZED", status, resp.Code)
	}
}

func TestAuthRegisterValidation(t *testing.T) {
	r := newRouter(t)

	cases := []struct {
		name string
		body map[string]string
	}{
		{"short username", map[string]string{"username": "ab", "password": "secret123"}},
		{"long username", map[string]string{"username": strings.Repeat("u", 33), "password": "secret123"}},
		{"short password", map[string]string{"username": "alice", "password": "12345"}},
		{"long password", map[string]string{"username": "alice", "password": strings.Repeat("p", 65)}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			status, resp := userDo(t, r, http.MethodPost, "/api/v1/auth/register", "", tc.body)
			if status != http.StatusBadRequest || resp.Code != "AUTH_INVALID_INPUT" {
				t.Fatalf("register: status = %d code = %s, want 400 AUTH_INVALID_INPUT", status, resp.Code)
			}
		})
	}

	// 非法 JSON → 400 AUTH_INVALID_INPUT。
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", bytes.NewReader([]byte("{not json")))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	var resp response
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil || w.Code != http.StatusBadRequest || resp.Code != "AUTH_INVALID_INPUT" {
		t.Fatalf("register invalid json: status = %d code = %s err = %v, want 400 AUTH_INVALID_INPUT", w.Code, resp.Code, err)
	}
}

func TestAuthRegisterDuplicate(t *testing.T) {
	r := newRouter(t)

	registerUser(t, r)
	status, resp := userDo(t, r, http.MethodPost, "/api/v1/auth/register", "", map[string]string{
		"username": "alice", "password": "another-pass",
	})
	if status != http.StatusConflict || resp.Code != "AUTH_USERNAME_TAKEN" {
		t.Fatalf("duplicate register: status = %d code = %s, want 409 AUTH_USERNAME_TAKEN", status, resp.Code)
	}
}

func TestAuthLoginWrongCredentials(t *testing.T) {
	r := newRouter(t)
	registerUser(t, r)

	// 错密码：401 AUTH_INVALID_CREDENTIALS。
	status, resp := userDo(t, r, http.MethodPost, "/api/v1/auth/login", "", map[string]string{
		"username": "alice", "password": "wrong-password",
	})
	if status != http.StatusUnauthorized || resp.Code != "AUTH_INVALID_CREDENTIALS" {
		t.Fatalf("login wrong password: status = %d code = %s, want 401 AUTH_INVALID_CREDENTIALS", status, resp.Code)
	}

	// 用户不存在：同样 401 AUTH_INVALID_CREDENTIALS（不区分提示）。
	status, resp = userDo(t, r, http.MethodPost, "/api/v1/auth/login", "", map[string]string{
		"username": "nosuchuser", "password": "secret123",
	})
	if status != http.StatusUnauthorized || resp.Code != "AUTH_INVALID_CREDENTIALS" {
		t.Fatalf("login unknown user: status = %d code = %s, want 401 AUTH_INVALID_CREDENTIALS", status, resp.Code)
	}

	// 登录入参不合法（密码过短）：400 AUTH_INVALID_INPUT。
	status, resp = userDo(t, r, http.MethodPost, "/api/v1/auth/login", "", map[string]string{
		"username": "alice", "password": "12345",
	})
	if status != http.StatusBadRequest || resp.Code != "AUTH_INVALID_INPUT" {
		t.Fatalf("login invalid input: status = %d code = %s, want 400 AUTH_INVALID_INPUT", status, resp.Code)
	}
}
