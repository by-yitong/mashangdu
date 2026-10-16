package api_test

// App 版本接口测试：latest（无认证，空表 404，enabled 中取最大 versionCode）、
// 管理端版本 CRUD 与 versionCode 冲突。

import (
	"encoding/json"
	"net/http"
	"strconv"
	"testing"

	"github.com/gin-gonic/gin"
)

// appVersionData 管理端返回的版本对象结构。
type appVersionData struct {
	ID          uint   `json:"id"`
	Version     string `json:"version"`
	VersionCode int    `json:"versionCode"`
	Notes       string `json:"notes"`
	ApkURL      string `json:"apkUrl"`
	Force       bool   `json:"force"`
	Enabled     bool   `json:"enabled"`
	ReleasedAt  string `json:"releasedAt"`
}

// newVersionBody 构造创建版本的请求体。
func newVersionBody(version string, code int, force bool) map[string]interface{} {
	return map[string]interface{}{
		"version":     version,
		"versionCode": code,
		"notes":       "更新说明 " + version,
		"apkUrl":      "https://example.com/app-" + version + ".apk",
		"force":       force,
	}
}

// createVersion 经管理端创建版本并断言 201。
func createVersion(t *testing.T, r *gin.Engine, version string, code int, force bool) appVersionData {
	t.Helper()
	status, resp := adminDo(t, r, http.MethodPost, "/api/v1/admin/app-versions", "dev123",
		newVersionBody(version, code, force))
	if status != http.StatusCreated || resp.Code != "OK" {
		t.Fatalf("create %s: status = %d code = %s, want 201 OK (body: %s)",
			version, status, resp.Code, resp.Data)
	}
	var data appVersionData
	if err := json.Unmarshal(resp.Data, &data); err != nil {
		t.Fatalf("unmarshal create data %s: %v", resp.Data, err)
	}
	return data
}

// getLatest 拉取 /app/latest；返回状态码与 data（data 仅在 200 时有效）。
func getLatest(t *testing.T, r *gin.Engine) (int, map[string]interface{}) {
	t.Helper()
	status, resp := doGet(t, r, "/api/v1/app/latest")
	if status != http.StatusOK {
		return status, nil
	}
	var data map[string]interface{}
	if err := json.Unmarshal(resp.Data, &data); err != nil {
		t.Fatalf("unmarshal latest data %s: %v", resp.Data, err)
	}
	return status, data
}

func TestAppLatestEmpty(t *testing.T) {
	r := newRouter(t)

	status, resp := doGet(t, r, "/api/v1/app/latest")
	if status != http.StatusNotFound || resp.Code != "NOT_FOUND" {
		t.Fatalf("latest on empty table: status = %d code = %s, want 404 NOT_FOUND", status, resp.Code)
	}
}

func TestAppLatestPicksMaxEnabled(t *testing.T) {
	t.Setenv("ADMIN_TOKEN", "dev123")
	r := newRouter(t)

	createVersion(t, r, "1.0.0", 1, false)
	latest3 := createVersion(t, r, "1.2.0", 3, true)
	createVersion(t, r, "1.1.0", 2, false)

	// 取 enabled 中 versionCode 最大一条；无认证可访问。
	status, data := getLatest(t, r)
	if status != http.StatusOK {
		t.Fatalf("latest: status = %d, want 200", status)
	}
	if data["version"] != "1.2.0" || data["versionCode"] != float64(3) {
		t.Fatalf("latest = %v, want version 1.2.0 code 3", data)
	}
	if data["apkUrl"] != latest3.ApkURL || data["notes"] != "更新说明 1.2.0" {
		t.Fatalf("latest apkUrl/notes = %v / %v", data["apkUrl"], data["notes"])
	}
	if force, _ := data["force"].(bool); !force {
		t.Fatalf("latest force = %v, want true", data["force"])
	}
	releasedAt, _ := data["releasedAt"].(string)
	assertRFC3339(t, "/app/latest", "releasedAt", releasedAt)

	// 禁用 1.2.0 → latest 变为 1.1.0（versionCode 2）。
	status, resp := adminDo(t, r, http.MethodPut, "/api/v1/admin/app-versions/"+strconv.FormatUint(uint64(latest3.ID), 10), "dev123", map[string]interface{}{
		"version": "1.2.0", "versionCode": 3, "notes": "更新说明 1.2.0",
		"apkUrl": latest3.ApkURL, "enabled": false,
	})
	if status != http.StatusOK || resp.Code != "OK" {
		t.Fatalf("disable 1.2.0: status = %d code = %s, want 200 OK", status, resp.Code)
	}
	status, data = getLatest(t, r)
	if status != http.StatusOK || data["version"] != "1.1.0" || data["versionCode"] != float64(2) {
		t.Fatalf("latest after disable = %v (status %d), want 1.1.0 / 2", data, status)
	}
}

func TestAdminAppVersionCRUD(t *testing.T) {
	t.Setenv("ADMIN_TOKEN", "dev123")
	r := newRouter(t)

	// 管理端鉴权仍生效。
	if status, resp := adminDo(t, r, http.MethodGet, "/api/v1/admin/app-versions", "", nil); status != http.StatusForbidden {
		t.Fatalf("list without token: status = %d code = %s, want 403", status, resp.Code)
	}

	// 入参校验：version/apkUrl 非空、versionCode>0 → 400 BAD_REQUEST。
	for name, body := range map[string]map[string]interface{}{
		"missing version":  {"versionCode": 1, "apkUrl": "https://e.com/a.apk"},
		"missing apkUrl":   {"version": "1.0.0", "versionCode": 1},
		"zero versionCode": {"version": "1.0.0", "versionCode": 0, "apkUrl": "https://e.com/a.apk"},
	} {
		status, resp := adminDo(t, r, http.MethodPost, "/api/v1/admin/app-versions", "dev123", body)
		if status != http.StatusBadRequest || resp.Code != "BAD_REQUEST" {
			t.Fatalf("create with %s: status = %d code = %s, want 400 BAD_REQUEST", name, status, resp.Code)
		}
	}

	// 创建：201，默认 enabled=true、force 按入参。
	v1 := createVersion(t, r, "1.0.0", 1, false)
	if v1.ID == 0 || !v1.Enabled || v1.Force {
		t.Fatalf("created version = %+v, want enabled=true force=false", v1)
	}
	assertRFC3339(t, "create app version", "releasedAt", v1.ReleasedAt)
	forced := createVersion(t, r, "1.1.0", 2, true)
	if !forced.Force {
		t.Fatalf("created version force = false, want true")
	}

	// versionCode 重复 → 409 VERSION_CONFLICT。
	status, resp := adminDo(t, r, http.MethodPost, "/api/v1/admin/app-versions", "dev123", newVersionBody("1.2.0", 2, false))
	if status != http.StatusConflict || resp.Code != "VERSION_CONFLICT" {
		t.Fatalf("duplicate versionCode: status = %d code = %s, want 409 VERSION_CONFLICT", status, resp.Code)
	}

	// 列表：versionCode 降序。
	status, resp = adminDo(t, r, http.MethodGet, "/api/v1/admin/app-versions", "dev123", nil)
	if status != http.StatusOK || resp.Code != "OK" {
		t.Fatalf("list: status = %d code = %s, want 200 OK", status, resp.Code)
	}
	var list []appVersionData
	if err := json.Unmarshal(resp.Data, &list); err != nil {
		t.Fatalf("unmarshal list: %v", err)
	}
	if len(list) != 2 || list[0].VersionCode != 2 || list[1].VersionCode != 1 {
		t.Fatalf("list = %+v, want versionCode desc [2 1]", list)
	}

	// 更新：改 notes/apkUrl/force/enabled；返回更新后对象。
	status, resp = adminDo(t, r, http.MethodPut, "/api/v1/admin/app-versions/1", "dev123", map[string]interface{}{
		"version": "1.0.1", "versionCode": 1, "notes": "新说明",
		"apkUrl": "https://example.com/app-1.0.1.apk", "force": true, "enabled": false,
	})
	if status != http.StatusOK || resp.Code != "OK" {
		t.Fatalf("update: status = %d code = %s, want 200 OK", status, resp.Code)
	}
	var updated appVersionData
	if err := json.Unmarshal(resp.Data, &updated); err != nil {
		t.Fatalf("unmarshal update data: %v", err)
	}
	if updated.Version != "1.0.1" || updated.Notes != "新说明" || !updated.Force || updated.Enabled {
		t.Fatalf("updated version = %+v, want 1.0.1/新说明/force=true/enabled=false", updated)
	}

	// 更新时把 versionCode 改成与别人冲突 → 409。
	status, resp = adminDo(t, r, http.MethodPut, "/api/v1/admin/app-versions/1", "dev123", map[string]interface{}{
		"version": "1.0.1", "versionCode": 2, "apkUrl": "https://example.com/a.apk",
	})
	if status != http.StatusConflict || resp.Code != "VERSION_CONFLICT" {
		t.Fatalf("update to duplicate versionCode: status = %d code = %s, want 409 VERSION_CONFLICT", status, resp.Code)
	}

	// 更新/删除不存在的 id → 404。
	for _, method := range []string{http.MethodPut, http.MethodDelete} {
		status, resp = adminDo(t, r, method, "/api/v1/admin/app-versions/999", "dev123", map[string]interface{}{
			"version": "9.9.9", "versionCode": 99, "apkUrl": "https://example.com/a.apk",
		})
		if status != http.StatusNotFound || resp.Code != "NOT_FOUND" {
			t.Fatalf("%s missing id: status = %d code = %s, want 404 NOT_FOUND", method, status, resp.Code)
		}
	}

	// 删除 → {"ok":true}；再删 → 404。
	status, resp = adminDo(t, r, http.MethodDelete, "/api/v1/admin/app-versions/2", "dev123", nil)
	if status != http.StatusOK || resp.Code != "OK" || string(resp.Data) != `{"ok":true}` {
		t.Fatalf("delete: status = %d code = %s data = %s, want 200 {\"ok\":true}", status, resp.Code, resp.Data)
	}
	status, resp = adminDo(t, r, http.MethodDelete, "/api/v1/admin/app-versions/2", "dev123", nil)
	if status != http.StatusNotFound || resp.Code != "NOT_FOUND" {
		t.Fatalf("delete again: status = %d code = %s, want 404 NOT_FOUND", status, resp.Code)
	}
}
