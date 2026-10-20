package api

// 管理端用户管理：GET /api/v1/admin/users（分页列表，支持 q 模糊过滤）与
// DELETE /api/v1/admin/users/{id}（单事务级联删除该用户的评论/点赞/观看记录
// 后删用户，事务提交后尽力删除头像文件，失败仅记日志）。

import (
	"log"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"code-tutorials/backend/internal/model"
)

// adminUserItem 管理端用户列表单条结构（在用户公开字段上附加三类业务计数
// 与最近阅读时间）。
type adminUserItem struct {
	ID           uint   `json:"id"`
	Username     string `json:"username"`
	Avatar       string `json:"avatar"`
	CreatedAt    string `json:"createdAt"`
	CommentCount int64  `json:"commentCount"`
	LikeCount    int64  `json:"likeCount"`
	RecordCount  int64  `json:"recordCount"`
	LastReadAt   string `json:"lastReadAt"`
}

// GET /api/v1/admin/users?page=&pageSize=&q=
func (s *Server) adminListUsers(c *gin.Context) {
	page, pageSize := pageParams(c)
	q := c.Query("q")
	newQuery := func() *gorm.DB {
		query := s.db.Model(&model.User{})
		if q != "" {
			query = query.Where("username LIKE ?", "%"+q+"%")
		}
		return query
	}
	var total int64
	if err := newQuery().Count(&total).Error; err != nil {
		s.internalError(c, err)
		return
	}
	var users []model.User
	if err := newQuery().Order("created_at DESC, id DESC").
		Limit(pageSize).Offset((page - 1) * pageSize).
		Find(&users).Error; err != nil {
		s.internalError(c, err)
		return
	}

	// 先分页查用户，再按本页 user_id 集合分组聚合后 map 回填，避免 JOIN 行放大。
	ids := make([]uint, 0, len(users))
	for _, user := range users {
		ids = append(ids, user.ID)
	}
	commentBy := make(map[uint]int64, len(users))
	likeBy := make(map[uint]int64, len(users))
	recordBy := make(map[uint]int64, len(users))
	lastReadBy := make(map[uint]string, len(users))
	if len(ids) > 0 {
		// 三类业务行数共用同一个分组 COUNT 查询形状。
		countsOf := func(table interface{}, dest map[uint]int64) error {
			var rows []struct {
				UserID uint
				Cnt    int64
			}
			if err := s.db.Model(table).
				Where("user_id IN ?", ids).
				Select("user_id, COUNT(*) AS cnt").
				Group("user_id").
				Scan(&rows).Error; err != nil {
				return err
			}
			for _, row := range rows {
				dest[row.UserID] = row.Cnt
			}
			return nil
		}
		for _, item := range []struct {
			table interface{}
			dest  map[uint]int64
		}{
			{&model.ChapterComment{}, commentBy},
			{&model.ChapterLike{}, likeBy},
			{&model.ReadingRecord{}, recordBy},
		} {
			if err := countsOf(item.table, item.dest); err != nil {
				s.internalError(c, err)
				return
			}
		}
		// MAX(read_at) 无记录时为 NULL，保持缺省空串即可；聚合结果不走列
		// 类型转换，驱动按字符串返回，这里解析回 UTC 时间再格式化。
		var reads []struct {
			UserID   uint
			LastRead *string
		}
		if err := s.db.Model(&model.ReadingRecord{}).
			Where("user_id IN ?", ids).
			Select("user_id, MAX(read_at) AS last_read").
			Group("user_id").
			Scan(&reads).Error; err != nil {
			s.internalError(c, err)
			return
		}
		for _, row := range reads {
			if row.LastRead == nil {
				continue
			}
			parsed, err := time.Parse(time.RFC3339Nano, *row.LastRead)
			if err != nil {
				// glebarez/sqlite 的时间序列化布局（与驱动写入格式一致）。
				if parsed, err = time.Parse("2006-01-02 15:04:05.999999999-07:00", *row.LastRead); err != nil {
					s.internalError(c, err)
					return
				}
			}
			lastReadBy[row.UserID] = parsed.UTC().Format(time.RFC3339)
		}
	}

	items := make([]adminUserItem, 0, len(users))
	for _, user := range users {
		items = append(items, adminUserItem{
			ID:           user.ID,
			Username:     user.Username,
			Avatar:       user.Avatar,
			CreatedAt:    user.CreatedAt.UTC().Format(time.RFC3339),
			CommentCount: commentBy[user.ID],
			LikeCount:    likeBy[user.ID],
			RecordCount:  recordBy[user.ID],
			LastReadAt:   lastReadBy[user.ID],
		})
	}
	ok(c, gin.H{
		"users":     items,
		"total":     total,
		"page":      page,
		"pageSize":  pageSize,
		"pageCount": pageCount(total, pageSize),
	})
}

// findAdminUser 按路径 id 查用户；id 非数字、为 0 或不存在时已写 404 响应
// （与 findComment 同款模式）。
func (s *Server) findAdminUser(c *gin.Context) (model.User, bool) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || id == 0 {
		fail(c, http.StatusNotFound, "NOT_FOUND", "user not found")
		return model.User{}, false
	}
	var user model.User
	if err := s.db.First(&user, uint(id)).Error; err != nil {
		s.notFoundOrInternal(c, err, "user not found")
		return user, false
	}
	return user, true
}

// DELETE /api/v1/admin/users/{id}
func (s *Server) adminDeleteUser(c *gin.Context) {
	user, found := s.findAdminUser(c)
	if !found {
		return
	}
	// 单事务内先清该用户的三类业务行再删用户，保证不留孤儿数据。
	if err := s.db.Transaction(func(tx *gorm.DB) error {
		for _, table := range []interface{}{
			&model.ChapterComment{}, &model.ChapterLike{}, &model.ReadingRecord{},
		} {
			if err := tx.Where("user_id = ?", user.ID).Delete(table).Error; err != nil {
				return err
			}
		}
		return tx.Delete(&user).Error
	}); err != nil {
		s.internalError(c, err)
		return
	}
	// 事务提交后尽力删除头像文件：失败仅记日志，不影响响应。
	if user.Avatar != "" {
		if err := os.Remove(filepath.Join(avatarsRoot, path.Base(user.Avatar))); err != nil {
			log.Printf("admin delete user %d: remove avatar %s: %v", user.ID, user.Avatar, err)
		}
	}
	ok(c, gin.H{"deleted": true})
}
