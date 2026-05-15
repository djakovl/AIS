package dto

import "time"

type TaskFilter struct {
	UserID       string
	StatusID     *string
	PriorityID   *string
	IsCompleted  *bool
	ParentTaskID *string
	Search       *string
	DueBefore    *time.Time
	DueAfter     *time.Time
	Page         int
	Limit        int
}