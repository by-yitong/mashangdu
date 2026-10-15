// 命令 code-tutorials/backend：教程内容 API 服务入口。
package main

import (
	"log"
	"os"

	"github.com/gin-gonic/gin"

	"code-tutorials/backend/internal/api"
	"code-tutorials/backend/internal/store"
)

func envOrDefault(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func main() {
	port := envOrDefault("PORT", "8080")
	dbPath := envOrDefault("TUTORIALS_DB", "data/tutorials.db")

	db, err := store.Open(dbPath)
	if err != nil {
		log.Fatalf("init store: %v", err)
	}

	gin.SetMode(gin.ReleaseMode)
	router := api.NewRouter(db)

	log.Printf("code-tutorials backend listening on :%s (db: %s)", port, dbPath)
	if err := router.Run(":" + port); err != nil {
		log.Fatalf("server: %v", err)
	}
}
