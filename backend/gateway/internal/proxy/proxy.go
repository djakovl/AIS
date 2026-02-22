package proxy

import (
	"fmt"
	"net/http"
	"net/http/httputil"
	"net/url"
	"time"

	"gateway/internal/middleware"
	"gateway/internal/response"
)

func New(targetURL string) http.Handler {
	target, err := url.Parse(targetURL)
	if err != nil {
		panic(fmt.Sprintf("Неверный URL сервиса: %s", targetURL))
	}

	proxy := httputil.NewSingleHostReverseProxy(target)

	// Настраиваем transport с таймаутами
	proxy.Transport = &http.Transport{
		ResponseHeaderTimeout: 30 * time.Second,
		IdleConnTimeout:       90 * time.Second,
	}

	// Кастомный ErrorHandler
	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		response.Error(w, http.StatusBadGateway, "SERVICE_UNAVAILABLE",
			fmt.Sprintf("Сервис недоступен: %v", err))
	}

	// Director: модифицируем запрос перед проксированием
	originalDirector := proxy.Director
	proxy.Director = func(req *http.Request) {
		originalDirector(req)

		// Инжектируем контекст пользователя из сессии
		ctx := req.Context()
		if userID := middleware.CtxGet(ctx, middleware.CtxUserID); userID != "" {
			req.Header.Set("X-User-Id", userID)
			req.Header.Set("X-User-Roles", middleware.CtxGet(ctx, middleware.CtxRoles))
		}

		// Убираем внутренние заголовки сессии — бэкенд их не должен видеть
		req.Header.Del("Cookie")
		req.Header.Del("X-Session-Token")
		req.Header.Del("X-CSRF-Token")

		// Передаём реальный IP клиента
		if ip := req.Header.Get("X-Real-IP"); ip != "" {
			req.Header.Set("X-Forwarded-For", ip)
		}

		req.Host = target.Host
	}

	return proxy
}
