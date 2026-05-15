package middleware

import (
	"fmt"
	"net/http"
	"strconv"
	"time"

	"gateway/internal/response"

	"github.com/redis/go-redis/v9"
)

var publicRoutes = map[string]bool{
	"/auth/login":    true,
	"/auth/register": true,
	"/health":        true,
}

func Session(rdb *redis.Client, ttl int) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
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

			fields, err := rdb.HGetAll(ctx, key).Result()
			if err != nil || len(fields) == 0 {
				response.Error(w, http.StatusUnauthorized, "SESSION_EXPIRED", "Сессия истекла или не найдена")
				return
			}

			// Обновляем last_activity — ошибка некритична, продолжаем работу в любом случае
			pipe := rdb.Pipeline()
			pipe.HSet(ctx, key, "last_activity", strconv.FormatInt(time.Now().Unix(), 10))
			pipe.Expire(ctx, key, time.Duration(ttl)*time.Second)
			_, _ = pipe.Exec(ctx)

			ctx = ctxSet(ctx, CtxUserID, fields["user_id"])
			ctx = ctxSet(ctx, CtxRoles, fields["roles"])
			ctx = ctxSet(ctx, CtxCSRFToken, fields["csrf_token"])
			ctx = ctxSet(ctx, CtxSessionID, sessionID)

			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func extractSessionID(r *http.Request) string {
	if cookie, err := r.Cookie("session_id"); err == nil {
		return cookie.Value
	}
	return r.Header.Get("X-Session-Token")
}
