// services/task_service.go
package services

import (
	"time"
	"task-service/dto"
	"task-service/models"
	"task-service/repository"
)

type TaskService struct {
	Repo *repository.TaskRepository
}

func NewTaskService(repo *repository.TaskRepository) *TaskService {
	return &TaskService{Repo: repo}
}

// =====================
// WRITE OPERATIONS (Models)
// =====================

// Create принимает простую модель для записи в БД
func (s *TaskService) Create(task *models.Task) error {
	// Устанавливаем время создания, если нужно
	if task.CreatedAt.IsZero() {
		task.CreatedAt = time.Now()
	}
	if task.UpdatedAt.IsZero() {
		task.UpdatedAt = time.Now()
	}
	return s.Repo.Create(task)
}

// Get возвращает простую модель (для внутренней логики)
func (s *TaskService) Get(id string) (*models.Task, error) {
	return s.Repo.GetByID(id)
}

// Update принимает простую модель
func (s *TaskService) Update(task *models.Task) error {
	task.UpdatedAt = time.Now()
	return s.Repo.Update(task)
}

func (s *TaskService) Delete(id string) error {
	return s.Repo.Delete(id)
}

// =====================
// READ OPERATIONS (DTOs with Relations)
// =====================

// GetWithRelations возвращает полный ответ для API (с status и priority)
func (s *TaskService) GetWithRelations(id string) (*dto.TaskResponse, error) {
	return s.Repo.GetByIDWithRelations(id)
}

// FilterWithRelations возвращает список с полными данными
func (s *TaskService) FilterWithRelations(f dto.TaskFilter) ([]dto.TaskResponse, error) {
	return s.Repo.FilterWithRelations(f)
}