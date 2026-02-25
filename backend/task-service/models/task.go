// models/task.go
package models

import "time"

type Task struct {
	ID           string     `json:"id"`
	UserID       string     `json:"user_id"`
	ParentTaskID *string    `json:"parent_task_id"`
	Title        string     `json:"title"`
	Description  *string    `json:"description"`
	StatusID     string     `json:"status_id"`
	PriorityID   string     `json:"priority_id"`
	DueDate      *time.Time `json:"due_date"`
	CompletedAt  *time.Time `json:"completed_at"`
	IsCompleted  bool       `json:"is_completed"`
	OrderIndex   int        `json:"order_index"`
	CreatedAt    time.Time  `json:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at"`
}