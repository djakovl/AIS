// dto/task_request.go
package dto



// =====================
// ЗАПРОСЫ (Request DTOs)
// =====================

// CreateTaskRequest - данные для создания задачи
type CreateTaskRequest struct {
	ParentTaskID *string `json:"parent_task_id"`
	Title        string  `json:"title" binding:"required"`
	Description  *string `json:"description"`
	StatusID     string  `json:"status_id" binding:"required"`
	PriorityID   string  `json:"priority_id" binding:"required"`
	DueDate      *string `json:"due_date"` // RFC3339 format: "2026-03-31T23:59:59Z"
}

// UpdateTaskRequest - данные для обновления задачи (все поля опциональны)
type UpdateTaskRequest struct {
	Title        *string `json:"title"`
	Description  *string `json:"description"`
	StatusID     *string `json:"status_id"`
	PriorityID   *string `json:"priority_id"`
	DueDate      *string `json:"due_date"`
	IsCompleted  *bool   `json:"is_completed"`
}

