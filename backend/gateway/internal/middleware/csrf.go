package middleware

import (
	"net/http"
	"strings"

	"gateway/internal/response"
)

var csrfMethods = map[string]bool{
	http.MethodPost:   true,
	http.MethodPut:    true,
	http.MethodPatch:  true,
	http.MethodDelete: true,
}

func CSRF() func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Skip CSRF for public routes
			if publicRoutes[r.URL.Path] || !csrfMethods[r.Method] {
				next.ServeHTTP(w, r)
				return
			}

			// Skip CSRF for task service - session is already validated
			if strings.HasPrefix(r.URL.Path, "/tasks/") {
				next.ServeHTTP(w, r)
				return
			}

			receivedToken := r.Header.Get("X-CSRF-Token")
			if receivedToken == "" {
				response.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "X-CSRF-Token отсутствует")
				return
			}

			storedToken := CtxGet(r.Context(), CtxCSRFToken)
			if storedToken == "" || receivedToken != storedToken {
				response.Error(w, http.StatusForbidden, "CSRF_TOKEN_INVALID", "Неверный CSRF токен")
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}
