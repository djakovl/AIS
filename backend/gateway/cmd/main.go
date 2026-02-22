package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"gateway/internal/config"
	"gateway/internal/middleware"
	"gateway/internal/proxy"
	"gateway/internal/response"

	"github.com/redis/go-redis/v9"
)

func main() {
	cfg := config.Load()

	// Подключение к Redis
	rdb := redis.NewClient(&redis.Options{
		Addr:     cfg.RedisAddr,
		Password: cfg.RedisPassword,
		DB:       cfg.RedisDB,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Fatalf("Не удалось подключиться к Redis: %v", err)
	}
	log.Println("Redis: подключение успешно")

	// Инициализация прокси к микросервисам
	authProxy := proxy.New(cfg.AuthServiceURL)
	taskProxy := proxy.New(cfg.TaskServiceURL)
	s3Proxy := proxy.New(cfg.S3ServiceURL)

	// Middleware цепочка: сессия + CSRF
	authMW := func(h http.Handler) http.Handler {
		return middleware.Chain(h,
			middleware.Session(rdb, cfg.SessionTTL),
			middleware.CSRF(),
		)
	}

	// Маршрутизация
	mux := http.NewServeMux()

	// Health check
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		ping := rdb.Ping(r.Context()).Err()
		if ping != nil {
			response.Error(w, http.StatusServiceUnavailable, "REDIS_UNAVAILABLE", "Redis недоступен")
			return
		}
		response.JSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	// Auth Service — /auth/* (сессия проверяется внутри middleware, login/register — пропускаются)
	mux.Handle("/auth/", authMW(authProxy))

	// Task Service — /tasks/*
	mux.Handle("/tasks/", authMW(taskProxy))

	// S3 Service — /files/*
	mux.Handle("/files/", authMW(s3Proxy))

	// HTTP сервер
	server := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      middleware.Logger(mux),
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Graceful shutdown
	go func() {
		log.Printf("Gateway запущен на порту %s", cfg.Port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Ошибка сервера: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Завершение работы Gateway...")
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer shutdownCancel()
	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Fatalf("Принудительное завершение: %v", err)
	}
	log.Println("Gateway остановлен")
}
