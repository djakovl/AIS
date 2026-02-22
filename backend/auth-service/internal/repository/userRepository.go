package repository

import (
	"database/sql"
	"errors"

	"auth-service/internal/models"

	"github.com/lib/pq"
)

type UserRepository struct{ db *sql.DB }

func NewUserRepository(db *sql.DB) *UserRepository {
	return &UserRepository{db: db}
}

func (r *UserRepository) Create(user *models.User) error {
	query := `
		INSERT INTO auth.users (email, password_hash, username, first_name, last_name, roles, is_active)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, created_at, updated_at
	`
	return r.db.QueryRow(query,
		user.Email, user.PasswordHash, user.Username,
		user.FirstName, user.LastName, pq.Array(user.Roles), user.IsActive,
	).Scan(&user.ID, &user.CreatedAt, &user.UpdatedAt)
}

func (r *UserRepository) FindByEmail(email string) (*models.User, error) {
	query := `SELECT id, email, password_hash, username, first_name, last_name, roles, is_active, created_at, updated_at
		FROM auth.users WHERE email = $1`
	user := &models.User{}
	err := r.db.QueryRow(query, email).Scan(
		&user.ID, &user.Email, &user.PasswordHash, &user.Username,
		&user.FirstName, &user.LastName, pq.Array(&user.Roles),
		&user.IsActive, &user.CreatedAt, &user.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, errors.New("user not found")
	}
	return user, err
}

func (r *UserRepository) FindByID(id string) (*models.User, error) {
	query := `SELECT id, email, password_hash, username, first_name, last_name, roles, is_active, created_at, updated_at
		FROM auth.users WHERE id = $1`
	user := &models.User{}
	err := r.db.QueryRow(query, id).Scan(
		&user.ID, &user.Email, &user.PasswordHash, &user.Username,
		&user.FirstName, &user.LastName, pq.Array(&user.Roles),
		&user.IsActive, &user.CreatedAt, &user.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, errors.New("user not found")
	}
	return user, err
}
