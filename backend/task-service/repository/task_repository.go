// repository/task_repository.go
package repository

import (
	"database/sql"
	"fmt"
	"task-service/dto"
	"task-service/models"

)

type TaskRepository struct {
	DB *sql.DB
}

func NewTaskRepository(db *sql.DB) *TaskRepository {
	return &TaskRepository{DB: db}
}

// =====================
// WRITE OPERATIONS (Models)
// =====================

func (r *TaskRepository) Create(task *models.Task) error {
	query := `
	INSERT INTO tasks (user_id, parent_task_id, title, description, status_id, priority_id, due_date)
	VALUES ($1, $2, $3, $4, $5, $6, $7)
	RETURNING id, created_at, updated_at
	`
	return r.DB.QueryRow(
		query,
		task.UserID, task.ParentTaskID, task.Title, task.Description,
		task.StatusID, task.PriorityID, task.DueDate,
	).Scan(&task.ID, &task.CreatedAt, &task.UpdatedAt)
}

func (r *TaskRepository) GetByID(id string) (*models.Task, error) {
	query := `
	SELECT id, user_id, parent_task_id, title, description, status_id, priority_id, 
           due_date, completed_at, is_completed, order_index, created_at, updated_at
	FROM tasks WHERE id = $1
	`
	row := r.DB.QueryRow(query, id)

	var t models.Task
	var parentTaskID, description sql.NullString
	var dueDate, completedAt sql.NullTime

	err := row.Scan(
		&t.ID, &t.UserID, &parentTaskID, &t.Title, &description,
		&t.StatusID, &t.PriorityID, &dueDate, &completedAt,
		&t.IsCompleted, &t.OrderIndex, &t.CreatedAt, &t.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}

	if parentTaskID.Valid { t.ParentTaskID = &parentTaskID.String }
	if description.Valid { t.Description = &description.String }
	if dueDate.Valid { t.DueDate = &dueDate.Time }
	if completedAt.Valid { t.CompletedAt = &completedAt.Time }

	return &t, nil
}

func (r *TaskRepository) Update(task *models.Task) error {
	query := `
	UPDATE tasks SET
	title = $1, description = $2, status_id = $3, priority_id = $4,
	due_date = $5, is_completed = $6, completed_at = $7, updated_at = $8
	WHERE id = $9
	`
	_, err := r.DB.Exec(
		query,
		task.Title, task.Description, task.StatusID, task.PriorityID,
		task.DueDate, task.IsCompleted, task.CompletedAt, task.UpdatedAt, task.ID,
	)
	return err
}

func (r *TaskRepository) Delete(id string) error {
	_, err := r.DB.Exec("DELETE FROM tasks WHERE id = $1", id)
	return err
}

// =====================
// READ OPERATIONS (DTOs with Relations)
// =====================

func (r *TaskRepository) GetByIDWithRelations(id string) (*dto.TaskResponse, error) {
	query := `
	SELECT 
		t.id, t.user_id, t.parent_task_id, t.title, t.description,
		t.status_id, t.priority_id, t.due_date, t.completed_at,
		t.is_completed, t.order_index, t.created_at, t.updated_at,
		s.id, s.name, s.color, s.order_index,
		p.id, p.name, p.color, p.eisenhower_quad
	FROM tasks t
	LEFT JOIN statuses s ON t.status_id = s.id
	LEFT JOIN priorities p ON t.priority_id = p.id
	WHERE t.id = $1
	`
	row := r.DB.QueryRow(query, id)
	return scanTaskFromRow(row)
}

func (r *TaskRepository) FilterWithRelations(f dto.TaskFilter) ([]dto.TaskResponse, error) {
	query := `
	SELECT 
		t.id, t.user_id, t.parent_task_id, t.title, t.description,
		t.status_id, t.priority_id, t.due_date, t.completed_at,
		t.is_completed, t.order_index, t.created_at, t.updated_at,
		s.id, s.name, s.color, s.order_index,
		p.id, p.name, p.color, p.eisenhower_quad
	FROM tasks t
	LEFT JOIN statuses s ON t.status_id = s.id
	LEFT JOIN priorities p ON t.priority_id = p.id
	WHERE t.user_id = $1
	`

	args := []interface{}{f.UserID}
	argIndex := 2

	if f.StatusID != nil {
		query += fmt.Sprintf(" AND t.status_id = $%d", argIndex)
		args = append(args, *f.StatusID)
		argIndex++
	}
	if f.PriorityID != nil {
		query += fmt.Sprintf(" AND t.priority_id = $%d", argIndex)
		args = append(args, *f.PriorityID)
		argIndex++
	}
	if f.Search != nil {
		query += fmt.Sprintf(" AND LOWER(t.title) LIKE LOWER($%d)", argIndex)
		args = append(args, "%"+*f.Search+"%")
		argIndex++
	}
	if f.IsCompleted != nil {
		query += fmt.Sprintf(" AND t.is_completed = $%d", argIndex)
		args = append(args, *f.IsCompleted)
		argIndex++
	}

	query += " ORDER BY t.order_index"

	if f.Limit <= 0 { f.Limit = 20 }
	if f.Page <= 0 { f.Page = 1 }
	offset := (f.Page - 1) * f.Limit
	query += fmt.Sprintf(" LIMIT %d OFFSET %d", f.Limit, offset)

	rows, err := r.DB.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tasks []dto.TaskResponse
	for rows.Next() {
		task, err := scanTaskFromRows(rows)
		if err != nil {
			return nil, err
		}
		tasks = append(tasks, *task)
	}

	return tasks, nil
}

// =====================
// HELPERS
// =====================

func scanTaskFromRow(row *sql.Row) (*dto.TaskResponse, error) {
	var t dto.TaskResponse
	var statusID, priorityID string
	var parentTaskID, description, dueDate, completedAt sql.NullString

	err := row.Scan(
		&t.ID, &t.UserID, &parentTaskID, &t.Title, &description,
		&statusID, &priorityID, &dueDate, &completedAt,
		&t.IsCompleted, &t.OrderIndex, &t.CreatedAt, &t.UpdatedAt,
		&t.Status.ID, &t.Status.Name, &t.Status.Color, &t.Status.OrderIndex,
		&t.Priority.ID, &t.Priority.Name, &t.Priority.Color, &t.Priority.EisenhowerQuad,
	)
	if err != nil {
		return nil, err
	}

	if parentTaskID.Valid { t.ParentTaskID = &parentTaskID.String }
	if description.Valid { t.Description = &description.String }
	if dueDate.Valid { t.DueDate = &dueDate.String }
	if completedAt.Valid { t.CompletedAt = &completedAt.String }

	t.Status.ID = statusID
	t.Priority.ID = priorityID

	return &t, nil
}

func scanTaskFromRows(rows *sql.Rows) (*dto.TaskResponse, error) {
	var t dto.TaskResponse
	var statusID, priorityID string
	var parentTaskID, description, dueDate, completedAt sql.NullString

	err := rows.Scan(
		&t.ID, &t.UserID, &parentTaskID, &t.Title, &description,
		&statusID, &priorityID, &dueDate, &completedAt,
		&t.IsCompleted, &t.OrderIndex, &t.CreatedAt, &t.UpdatedAt,
		&t.Status.ID, &t.Status.Name, &t.Status.Color, &t.Status.OrderIndex,
		&t.Priority.ID, &t.Priority.Name, &t.Priority.Color, &t.Priority.EisenhowerQuad,
	)
	if err != nil {
		return nil, err
	}

	if parentTaskID.Valid { t.ParentTaskID = &parentTaskID.String }
	if description.Valid { t.Description = &description.String }
	if dueDate.Valid { t.DueDate = &dueDate.String }
	if completedAt.Valid { t.CompletedAt = &completedAt.String }

	t.Status.ID = statusID
	t.Priority.ID = priorityID

	return &t, nil
}