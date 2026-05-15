package config

import (
	"os"
	"strconv"
)

type Config struct {
	Port           string
	RedisAddr      string
	RedisPassword  string
	RedisDB        int
	AuthServiceURL string
	TaskServiceURL string
	S3ServiceURL   string
	SessionTTL     int // seconds
}

func Load() *Config {
	redisDB, _ := strconv.Atoi(getEnv("REDIS_DB", "0"))
	sessionTTL, _ := strconv.Atoi(getEnv("SESSION_TTL", "1800"))

	return &Config{
		Port:           getEnv("PORT", "8080"),
		RedisAddr:      getEnv("REDIS_ADDR", "redis:6379"),
		RedisPassword:  getEnv("REDIS_PASSWORD", ""),
		RedisDB:        redisDB,
		AuthServiceURL: getEnv("AUTH_SERVICE_URL", "auth-service:3000"),
		TaskServiceURL: getEnv("TASK_SERVICE_URL", "task-service:3003"),
		S3ServiceURL:   getEnv("S3_SERVICE_URL", "s3-service:3002"),
		SessionTTL:     sessionTTL,
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
