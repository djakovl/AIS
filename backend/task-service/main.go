package main

import (
	"database/sql"
	"log"
	"net/http"
	"time"
	
	"github.com/gin-gonic/gin"
	"github.com/gin-contrib/cors"
	_ "github.com/lib/pq"
	
	"task-service/config"
	"task-service/handlers"
	"task-service/repository"
	"task-service/services"
)

func main() {
	cfg := config.Load()
	
	dsn := cfg.DSN()
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatalf("❌ Failed to connect to DB: %v", err)
	}
	
	if err := db.Ping(); err != nil {
		log.Fatalf("❌ DB ping failed: %v", err)
	}
	defer db.Close()
	
	log.Println("✅ Database connected")

	taskRepo := repository.NewTaskRepository(db)
	taskService := services.NewTaskService(taskRepo)
	taskHandler := handlers.NewTaskHandler(taskService)
	refHandler := handlers.NewReferenceHandler(db)
	
	r := gin.Default()
	
	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"http://localhost:3001"},
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Content-Type", "X-User-Id", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	}))

	tasks := r.Group("/tasks")
	{
		tasks.GET("", taskHandler.List)
		tasks.GET("/:id", taskHandler.Get)
		tasks.POST("", taskHandler.Create)
		tasks.PUT("/:id", taskHandler.Update)
		tasks.DELETE("/:id", taskHandler.Delete)
	}

	r.GET("/statuses", refHandler.ListStatuses)
	r.GET("/priorities", refHandler.ListPriorities)
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	log.Printf("🚀 Server starting on :%s", cfg.Port)
	if err := r.Run(":" + cfg.Port); err != nil {
		log.Fatalf("❌ Failed to start server: %v", err)
	}
}
