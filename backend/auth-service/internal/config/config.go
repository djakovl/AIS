package config

import (
	"fmt"
	"os"
	"strconv"
)

type Config struct {
	Port       string
	DBHost     string
	DBPort     string
	DBUser     string
	DBPassword string
	DBName     string
	RedisAddr  string
	RedisDB    int
	JWTSecret  string
	SessionTTL int
}

func Load() *Config {
	redisDB, _ := strconv.Atoi(getEnv("REDIS_DB", "0"))
	sessionTTL, _ := strconv.Atoi(getEnv("SESSION_TTL", "1800"))
	return &Config{
		Port:       getEnv("PORT", "3000"),
		DBHost:     getEnv("DB_HOST", "localhost"),
		DBPort:     getEnv("DB_PORT", "5432"),
		DBUser:     getEnv("DB_USER", "cloud_user"),
		DBPassword: getEnv("DB_PASSWORD", "cloud_pass_2026"),
		DBName:     getEnv("DB_NAME", "cloud_db"),
		RedisAddr:  getEnv("REDIS_ADDR", "localhost:6379"),
		RedisDB:    redisDB,
		JWTSecret:  getEnv("JWT_SECRET", "change-me-in-production"),
		SessionTTL: sessionTTL,
	}
}

func (c *Config) DSN() string {
	return fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		c.DBHost, c.DBPort, c.DBUser, c.DBPassword, c.DBName)
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
