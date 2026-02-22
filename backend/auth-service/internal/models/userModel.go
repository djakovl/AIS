package models

import "time"

type User struct {
	ID           string    `json:"id"`
	Email        string    `json:"email"`
	PasswordHash string    `json:"-"`
	Username     string    `json:"username"`
	FirstName    string    `json:"first_name"`
	LastName     string    `json:"last_name"`
	Roles        []string  `json:"roles"`
	IsActive     bool      `json:"is_active"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

type RegisterRequest struct {
	Email     string `json:"email"`
	Password  string `json:"password"`
	Username  string `json:"username"`
	FirstName string `json:"first_name"`
	LastName  string `json:"last_name"`
}

type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type LoginResponse struct {
	User      *User  `json:"user"`
	SessionID string `json:"session_id"`
	CSRFToken string `json:"csrf_token"`
}
