// main.go
package main

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	_ "github.com/lib/pq"

	"task-service/handlers"
	"task-service/repository"
	"task-service/services"
)

func main() {
	// =====================
	// 1. ПОДКЛЮЧЕНИЕ К БД
	// =====================
	dbHost := getEnv("DB_HOST", "localhost")
	dbPort := getEnv("DB_PORT", "5432")
	dbUser := getEnv("DB_USER", "postgres")
	dbPassword := getEnv("DB_PASSWORD", "qwerty123")
	dbName := getEnv("DB_NAME", "task_db")
	port := getEnv("PORT", "3003")

	dsn := fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=disable",
		dbUser, dbPassword, dbHost, dbPort, dbName)

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatalf("❌ Failed to connect to DB: %v", err)
	}

	// Retry connection with timeout
	for i := 0; i < 30; i++ {
		if err := db.Ping(); err == nil {
			log.Println("✅ Database connected")
			break
		}
		log.Printf("⏳ Waiting for database... (%d/30)", i+1)
		time.Sleep(1 * time.Second)
		if i == 29 {
			log.Fatalf("❌ DB ping failed after 30 retries: %v", err)
		}
	}
	defer db.Close()

	// =====================
	// 2. СОЗДАНИЕ ЗАВИСИМОСТЕЙ (Dependency Injection)
	// =====================

	// DB → Repository
	taskRepo := repository.NewTaskRepository(db)

	// Repository → Service
	taskService := services.NewTaskService(taskRepo)

	// Service → Handler
	taskHandler := handlers.NewTaskHandler(taskService)
	refHandler := handlers.NewReferenceHandler(db)

	// =====================
	// 3. НАСТРОЙКА GIN
	// =====================
	r := gin.Default()

	// CORS middleware
	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"*"},
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Content-Type", "X-User-Id", "X-CSRF-Token", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	}))

	// =====================
	// 4. РЕГИСТРАЦИЯ РОУТОВ
	// =====================
	tasks := r.Group("/tasks")
	{
		tasks.GET("", taskHandler.List)
		tasks.POST("", taskHandler.Create)
		tasks.GET("/statuses", refHandler.ListStatuses)     // ПЕРЕД /:id !
		tasks.GET("/priorities", refHandler.ListPriorities) // ПЕРЕД /:id !
		tasks.GET("/:id", taskHandler.Get)
		tasks.PUT("/:id", taskHandler.Update)
		tasks.DELETE("/:id", taskHandler.Delete)
	}

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	// =====================
	// 5. ЗАПУСК СЕРВЕРА
	// =====================
	log.Printf("🚀 Server starting on :%s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatalf("❌ Failed to start server: %v", err)
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
