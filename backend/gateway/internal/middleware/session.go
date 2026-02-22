package middleware

import (
	"fmt"
	"net/http"
	"strconv"
	"time"

	"gateway/internal/response"

	"github.com/redis/go-redis/v9"
)

// publicRoutes — эндпоинты без проверки сессии
var publicRoutes = map[string]bool{
	"/auth/login":    true,
	"/auth/register": true,
	"/health":        true,
}

func Session(rdb *redis.Client, ttl int) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Публичные маршруты пропускаем без проверки
			if publicRoutes[r.URL.Path] {
				next.ServeHTTP(w, r)
				return
			}

			sessionID := extractSessionID(r)
			if sessionID == "" {
				response.Error(w, http.StatusUnauthorized, "UNAUTHORIZED", "Сессия отсутствует")
				return
			}

			ctx := r.Context()
			key := fmt.Sprintf("session:%s", sessionID)

			// Получаем сессию из Redis
			fields, err := rdb.HGetAll(ctx, key).Result()
			if err != nil || len(fields) == 0 {
				response.Error(w, http.StatusUnauthorized, "SESSION_EXPIRED", "Сессия истекла или не найдена")
				return
			}

			// Обновляем время последней активности и TTL
			pipe := rdb.Pipeline()
			pipe.HSet(ctx, key, "last_activity", strconv.FormatInt(time.Now().Unix(), 10))
			pipe.Expire(ctx, key, time.Duration(ttl)*time.Second)
			pipe.Exec(ctx)

			// Добавляем данные сессии в контекст запроса
			ctx = ctxSet(ctx, CtxUserID, fields["user_id"])
			ctx = ctxSet(ctx, CtxRoles, fields["roles"])
			ctx = ctxSet(ctx, CtxCSRFToken, fields["csrf_token"])
			ctx = ctxSet(ctx, CtxSessionID, sessionID)

			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// extractSessionID — достаём session_id из cookie (web) или заголовка (mobile)
func extractSessionID(r *http.Request) string {
	// Web: Cookie
	if cookie, err := r.Cookie("session_id"); err == nil {
		return cookie.Value
	}
	// Mobile/Desktop: Header
	return r.Header.Get("X-Session-Token")
}
