package middleware

import (
	"fmt"
	"net/http"
	"time"

	"gateway/internal/response"

	"github.com/redis/go-redis/v9"
)

// RateLimit ограничивает количество запросов с одного IP до maxRequests за window.
// Использует Redis fixed-window counter. При недоступности Redis пропускает запрос (fail open).
func RateLimit(rdb *redis.Client, maxRequests int, window time.Duration) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ip := r.Header.Get("X-Real-IP")
			if ip == "" {
				ip = r.RemoteAddr
			}
			key := fmt.Sprintf("rl:%s:%s", r.URL.Path, ip)
			ctx := r.Context()

			count, err := rdb.Incr(ctx, key).Result()
			if err != nil {
				// Redis недоступен — fail open, не блокируем запрос
				next.ServeHTTP(w, r)
				return
			}
			if count == 1 {
				// Устанавливаем TTL только при создании ключа
				rdb.Expire(ctx, key, window)
			}
			if count > int64(maxRequests) {
				w.Header().Set("Retry-After", fmt.Sprintf("%.0f", window.Seconds()))
				response.Error(w, http.StatusTooManyRequests, "RATE_LIMIT_EXCEEDED", "Слишком много запросов, попробуйте позже")
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}
