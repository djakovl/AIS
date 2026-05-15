package proxy

import (
	"fmt"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
	"time"

	"gateway/internal/middleware"
	"gateway/internal/response"
)

func New(targetURL string, stripPrefix string) http.Handler {
	target, err := url.Parse(targetURL)
	if err != nil {
		panic(fmt.Sprintf("Неверный URL сервиса: %s", targetURL))
	}

	proxy := httputil.NewSingleHostReverseProxy(target)

	proxy.Transport = &http.Transport{
		ResponseHeaderTimeout: 30 * time.Second,
		IdleConnTimeout:       90 * time.Second,
	}

	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		response.Error(w, http.StatusBadGateway, "SERVICE_UNAVAILABLE",
			fmt.Sprintf("Сервис недоступен: %v", err))
	}

	originalDirector := proxy.Director
	proxy.Director = func(req *http.Request) {
		originalDirector(req)

		if stripPrefix != "" && strings.HasPrefix(req.URL.Path, stripPrefix) {
			req.URL.Path = strings.TrimPrefix(req.URL.Path, stripPrefix)
			if req.URL.Path == "" || req.URL.Path == "/" {
				req.URL.Path = "/"
			}
		}

		ctx := req.Context()
		if userID := middleware.CtxGet(ctx, middleware.CtxUserID); userID != "" {
			req.Header.Set("X-User-Id", userID)
			req.Header.Set("X-User-Roles", middleware.CtxGet(ctx, middleware.CtxRoles))
		}

		if sessionID := middleware.CtxGet(ctx, middleware.CtxSessionID); sessionID != "" {
			req.Header.Set("X-Session-Id", sessionID)
		}

		req.Header.Del("Cookie")
		req.Header.Del("X-Session-Token")
		req.Header.Del("X-CSRF-Token")

		if ip := req.Header.Get("X-Real-IP"); ip != "" {
			req.Header.Set("X-Forwarded-For", ip)
		}

		req.Host = target.Host
	}

	return proxy
}
