// main.go
package main

import (
	"database/sql"
	"log"
	"net/http"
	"time"
	
	"github.com/gin-gonic/gin"
	"github.com/gin-contrib/cors"
	_ "github.com/lib/pq" // или другой драйвер БД
	
	"task-service/handlers"
	"task-service/repository"
	"task-service/services"
)

func main() {
	// =====================
	// 1. ПОДКЛЮЧЕНИЕ К БД
	// =====================
	dsn := "postgres://postgres:qwerty123@localhost:5432/task_db?sslmode=disable"
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatalf("❌ Failed to connect to DB: %v", err)
	}
	
	if err := db.Ping(); err != nil {
		log.Fatalf("❌ DB ping failed: %v", err)
	}
	defer db.Close()
	
	log.Println("✅ Database connected")

	// =====================
	// 2. СОЗДАНИЕ ЗАВИСИМОСТЕЙ (Dependency Injection)
	// =====================
	
	// DB → Repository
	taskRepo := repository.NewTaskRepository(db)
	
	// Repository → Service
	taskService := services.NewTaskService(taskRepo)
	
	// Service → Handler
	taskHandler := handlers.NewTaskHandler(taskService) // 👈 Теперь передаём service, а не db
	refHandler := handlers.NewReferenceHandler(db)
	// =====================
	// 3. НАСТРОЙКА GIN
	// =====================
	r := gin.Default()
	
	// CORS middleware
	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"http://localhost:3001"},
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Content-Type", "X-User-Id", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	}))

	// =====================
	// 4. РЕГИСТРАЦИЯ РОУТОВ
	// =====================
	tasks := r.Group("/tasks")
	{
		tasks.GET("", taskHandler.List)           // GET /tasks
		tasks.GET("/:id", taskHandler.Get)        // GET /tasks/:id
		tasks.POST("", taskHandler.Create)        // POST /tasks
		tasks.PUT("/:id", taskHandler.Update)     // PUT /tasks/:id
		tasks.DELETE("/:id", taskHandler.Delete)  // DELETE /tasks/:id
	}


	// 👇 Роуты справочников
	r.GET("/statuses", refHandler.ListStatuses)
	r.GET("/priorities", refHandler.ListPriorities)
	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	// =====================
	// 5. ЗАПУСК СЕРВЕРА
	// =====================
	log.Println("🚀 Server starting on :3003")
	if err := r.Run(":3003"); err != nil {
		log.Fatalf("❌ Failed to start server: %v", err)
	}
}