package service

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
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
	if len(req.Password) < 6 {
		return nil, errors.New("пароль должен быть не менее 6 символов")
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
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
		if strings.Contains(err.Error(), "duplicate") || strings.Contains(err.Error(), "unique") {
			return nil, errors.New("пользователь с таким email уже существует")
		}
		return nil, err
	}

	return user, nil
}

func (s *AuthService) Login(ctx context.Context, req *models.LoginRequest, ip, userAgent string) (*models.LoginResponse, error) {
	user, err := s.userRepo.FindByEmail(strings.ToLower(req.Email))
	if err != nil {
		return nil, errors.New("неверный email или пароль")
	}
	if !user.IsActive {
		return nil, errors.New("аккаунт деактивирован")
	}
	if err = bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, errors.New("неверный email или пароль")
	}

	sessionID := uuid.New().String()
	csrfToken := generateToken(32)
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
		return nil, err
	}

	return &models.LoginResponse{User: user, SessionID: sessionID, CSRFToken: csrfToken}, nil
}

func (s *AuthService) Logout(ctx context.Context, sessionID string) error {
	return s.rdb.Del(ctx, fmt.Sprintf("session:%s", sessionID)).Err()
}

func (s *AuthService) GetProfile(userID string) (*models.User, error) {
	return s.userRepo.FindByID(userID)
}

func generateToken(length int) string {
	b := make([]byte, length)
	rand.Read(b)
	return hex.EncodeToString(b)
}
