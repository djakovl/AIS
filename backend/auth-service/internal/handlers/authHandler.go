package handlers

import (
	"encoding/json"
	"net/http"
	"strings"

	"auth-service/internal/models"
	"auth-service/internal/response"
	"auth-service/internal/service"
)

type AuthHandler struct {
	authService *service.AuthService
}

func NewAuthHandler(authService *service.AuthService) *AuthHandler {
	return &AuthHandler{authService: authService}
}

func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		response.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Метод не разрешён")
		return
	}
	var req models.RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Неверный формат запроса")
		return
	}

	user, err := h.authService.Register(&req)
	if err != nil {
		if strings.Contains(err.Error(), "уже существует") {
			response.Error(w, http.StatusConflict, "USER_EXISTS", err.Error())
		} else {
			response.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		}
		return
	}

	response.JSON(w, http.StatusCreated, user)
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		response.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Метод не разрешён")
		return
	}
	var req models.LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Неверный формат запроса")
		return
	}

	ip := r.Header.Get("X-Real-IP")
	if ip == "" {
		ip = r.RemoteAddr
	}

	loginResp, err := h.authService.Login(r.Context(), &req, ip, r.Header.Get("User-Agent"))
	if err != nil {
		response.Error(w, http.StatusUnauthorized, "INVALID_CREDENTIALS", err.Error())
		return
	}

	// session_id — HttpOnly, JS не читает (защита от XSS)
	http.SetCookie(w, &http.Cookie{
		Name:     "session_id",
		Value:    loginResp.SessionID,
		Path:     "/",
		MaxAge:   1800,
		HttpOnly: true,
		SameSite: http.SameSiteStrictMode,
	})

	// csrf_token — не HttpOnly, JS читает и шлёт в X-CSRF-Token (Double Submit Cookie)
	http.SetCookie(w, &http.Cookie{
		Name:     "csrf_token",
		Value:    loginResp.CSRFToken,
		Path:     "/",
		MaxAge:   1800,
		HttpOnly: false,
		SameSite: http.SameSiteStrictMode,
	})

	response.JSON(w, http.StatusOK, loginResp)
}

func (h *AuthHandler) Logout(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		response.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Метод не разрешён")
		return
	}
	sessionID := extractSessionID(r)
	if sessionID == "" {
		response.Error(w, http.StatusBadRequest, "SESSION_MISSING", "Сессия не найдена")
		return
	}

	if err := h.authService.Logout(r.Context(), sessionID); err != nil {
		response.Error(w, http.StatusInternalServerError, "LOGOUT_FAILED", "Ошибка при выходе")
		return
	}

	http.SetCookie(w, &http.Cookie{Name: "session_id", Value: "", Path: "/", MaxAge: -1})
	http.SetCookie(w, &http.Cookie{Name: "csrf_token", Value: "", Path: "/", MaxAge: -1})
	response.JSON(w, http.StatusOK, map[string]string{"message": "Выход выполнен"})
}

func (h *AuthHandler) Profile(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		response.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Метод не разрешён")
		return
	}
	userID := r.Header.Get("X-User-Id")
	if userID == "" {
		response.Error(w, http.StatusUnauthorized, "UNAUTHORIZED", "Требуется аутентификация")
		return
	}

	user, err := h.authService.GetProfile(userID)
	if err != nil {
		response.Error(w, http.StatusNotFound, "USER_NOT_FOUND", "Пользователь не найден")
		return
	}

	response.JSON(w, http.StatusOK, user)
}

func extractSessionID(r *http.Request) string {
	if id := r.Header.Get("X-Session-Id"); id != "" {
		return id
	}
	if cookie, err := r.Cookie("session_id"); err == nil {
		return cookie.Value
	}
	return r.Header.Get("X-Session-Token")
}
