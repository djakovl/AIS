// dto/task_response.go
package dto

import "task-service/models"

// =====================
// ОТВЕТЫ (Response DTOs)
// =====================

// TaskResponse - полная информация о задаче с вложенными status и priority
type TaskResponse struct {
	ID           string           `json:"id"`
	UserID       string           `json:"user_id"`
	ParentTaskID *string          `json:"parent_task_id,omitempty"`
	Title        string           `json:"title"`
	Description  *string          `json:"description,omitempty"`
	Status       models.Status    `json:"status"`       // 👈 вложенный объект
	Priority     models.Priority  `json:"priority"`     // 👈 вложенный объект
	DueDate      *string          `json:"due_date,omitempty"`
	CompletedAt  *string          `json:"completed_at,omitempty"`
	IsCompleted  bool             `json:"is_completed"`
	OrderIndex   int              `json:"order_index"`
	CreatedAt    string           `json:"created_at"`
	UpdatedAt    string           `json:"updated_at"`
}

// ListResponse - обёртка для списка задач с пагинацией
type ListResponse struct {
	Success bool           `json:"success"`
	Data    []TaskResponse `json:"data"`
	Total   int            `json:"total,omitempty"`
	Page    int            `json:"page,omitempty"`
	Limit   int            `json:"limit,omitempty"`
}

// SingleResponse - обёртка для одной задачи
type SingleResponse struct {
	Success bool         `json:"success"`
	Data    TaskResponse `json:"data"`
}