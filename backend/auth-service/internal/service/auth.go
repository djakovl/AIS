package service

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"log/slog"
	"net/mail"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/lib/pq"
	"github.com/redis/go-redis/v9"
	"golang.org/x/crypto/bcrypt"

	"auth-service/internal/models"
	"auth-service/internal/repository"
)

type AuthService struct {
	userRepo   *repository.UserRepository
	rdb        *redis.Client
	sessionTTL int
}

func NewAuthService(repo *repository.UserRepository, rdb *redis.Client, sessionTTL int) *AuthService {
	return &AuthService{userRepo: repo, rdb: rdb, sessionTTL: sessionTTL}
}

func (s *AuthService) Register(req *models.RegisterRequest) (*models.User, error) {
	if req.Email == "" || req.Password == "" || req.Username == "" {
		return nil, errors.New("email, password и username обязательны")
	}
	if _, err := mail.ParseAddress(req.Email); err != nil {
		return nil, errors.New("некорректный формат email")
	}
	if len(req.Password) < 8 {
		return nil, errors.New("пароль должен быть не менее 8 символов")
	}
	if len(req.Password) > 72 {
		return nil, errors.New("пароль не должен превышать 72 символа")
	}

	// bcrypt cost=12 — оптимальный баланс безопасности и производительности (2024+)
	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
	if err != nil {
		return nil, err
	}

	user := &models.User{
		Email:        strings.ToLower(req.Email),
		PasswordHash: string(hash),
		Username:     req.Username,
		FirstName:    req.FirstName,
		LastName:     req.LastName,
		Roles:        []string{"user"},
		IsActive:     true,
	}

	if err = s.userRepo.Create(user); err != nil {
		// Используем типизированную проверку pq-кода вместо string matching
		var pgErr *pq.Error
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			slog.Warn("registration failed: duplicate user", "email", req.Email)
			return nil, errors.New("пользователь с таким email уже существует")
		}
		slog.Error("registration failed", "email", req.Email, "error", err)
		return nil, err
	}

	slog.Info("user registered", "user_id", user.ID, "email", user.Email)
	return user, nil
}

func (s *AuthService) Login(ctx context.Context, req *models.LoginRequest, ip, userAgent string) (*models.LoginResponse, error) {
	user, err := s.userRepo.FindByEmail(strings.ToLower(req.Email))
	if err != nil {
		slog.Warn("login failed: user not found", "email", req.Email, "ip", ip)
		return nil, errors.New("неверный email или пароль")
	}
	if !user.IsActive {
		slog.Warn("login failed: account inactive", "user_id", user.ID, "ip", ip)
		return nil, errors.New("аккаунт деактивирован")
	}
	if err = bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		slog.Warn("login failed: wrong password", "user_id", user.ID, "ip", ip)
		return nil, errors.New("неверный email или пароль")
	}

	sessionID := uuid.New().String()
	csrfToken, err := generateToken(32)
	if err != nil {
		return nil, fmt.Errorf("ошибка генерации токена: %w", err)
	}
	key := fmt.Sprintf("session:%s", sessionID)

	pipe := s.rdb.Pipeline()
	pipe.HSet(ctx, key, map[string]interface{}{
		"user_id":       user.ID,
		"roles":         strings.Join(user.Roles, ","),
		"csrf_token":    csrfToken,
		"user_ip":       ip,
		"browser":       userAgent,
		"created_at":    strconv.FormatInt(time.Now().Unix(), 10),
		"last_activity": strconv.FormatInt(time.Now().Unix(), 10),
	})
	pipe.Expire(ctx, key, time.Duration(s.sessionTTL)*time.Second)
	if _, err = pipe.Exec(ctx); err != nil {
		slog.Error("login failed: session creation", "user_id", user.ID, "error", err)
		return nil, err
	}

	// Логируем только первые 8 символов session_id — не раскрываем полный токен в логах
	slog.Info("user logged in", "user_id", user.ID, "ip", ip, "session_prefix", sessionID[:8])
	return &models.LoginResponse{User: user, SessionID: sessionID, CSRFToken: csrfToken}, nil
}

func (s *AuthService) Logout(ctx context.Context, sessionID string) error {
	err := s.rdb.Del(ctx, fmt.Sprintf("session:%s", sessionID)).Err()
	if err != nil {
		slog.Error("logout failed", "session_prefix", sessionID[:8], "error", err)
		return err
	}
	slog.Info("user logged out", "session_prefix", sessionID[:8])
	return nil
}

func (s *AuthService) GetProfile(userID string) (*models.User, error) {
	return s.userRepo.FindByID(userID)
}

func generateToken(length int) (string, error) {
	b := make([]byte, length)
	if _, err := rand.Read(b); err != nil {
		return "", fmt.Errorf("ошибка чтения случайных байт: %w", err)
	}
	return hex.EncodeToString(b), nil
}
