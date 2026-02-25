package handlers

import (
	"database/sql"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"task-service/dto"
	"task-service/models"
	"task-service/services"
	"task-service/utils"
)

type TaskHandler struct {
	Service *services.TaskService
}

func NewTaskHandler(service *services.TaskService) *TaskHandler {
	return &TaskHandler{Service: service}
}

// =====================
// CREATE
// =====================
func (h *TaskHandler) Create(c *gin.Context) {
	var req dto.CreateTaskRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Invalid request body"})
		return
	}

	userID := c.GetHeader("X-User-Id")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "X-User-Id header is required"})
		return
	}

	// 👇 Парсим due_date из *string в *time.Time
	var dueDate *time.Time
	if req.DueDate != nil && *req.DueDate != "" {
		parsed, err := time.Parse(time.RFC3339, *req.DueDate)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"success": false, 
				"error": "Invalid due_date format. Use RFC3339 (e.g., 2026-03-31T23:59:59Z)",
			})
			return
		}
		dueDate = &parsed
	}

	// Создаём задачу
	task := &models.Task{
		UserID:       userID,
		ParentTaskID: req.ParentTaskID,
		Title:        req.Title,
		Description:  req.Description,
		StatusID:     req.StatusID,
		PriorityID:   req.PriorityID,
		DueDate:      dueDate, // 👈 Теперь *time.Time
	}

	if err := h.Service.Create(task); err != nil {
		utils.Error(c, http.StatusInternalServerError, err)
		return
	}

	// Возвращаем полную задачу с relations
	fullTask, err := h.Service.GetWithRelations(task.ID)
	if err != nil {
		c.JSON(http.StatusCreated, gin.H{"success": true, "data": task})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"success": true, "data": fullTask})
}
// =====================
// GET BY ID
// =====================
func (h *TaskHandler) Get(c *gin.Context) {
	id := c.Param("id")

	task, err := h.Service.GetWithRelations(id)
	if err != nil {
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "Task not found"})
			return
		}
		utils.Error(c, http.StatusInternalServerError, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": task})
}

// =====================
// LIST / FILTER
// =====================
func (h *TaskHandler) List(c *gin.Context) {
	userID := c.GetHeader("X-User-Id")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "X-User-Id header is required"})
		return
	}

	filter := dto.TaskFilter{UserID: userID}

	// Парсим query-параметры
	if v := c.Query("status_id"); v != "" {
		filter.StatusID = &v
	}
	if v := c.Query("priority_id"); v != "" {
		filter.PriorityID = &v
	}
	if v := c.Query("parent_task_id"); v != "" {
		filter.ParentTaskID = &v
	}
	if v := c.Query("search"); v != "" {
		filter.Search = &v
	}
	if v := c.Query("is_completed"); v != "" {
		if b, err := strconv.ParseBool(v); err == nil {
			filter.IsCompleted = &b
		}
	}
	if v := c.Query("due_before"); v != "" {
		if t, err := time.Parse(time.RFC3339, v); err == nil {
			filter.DueBefore = &t
		}
	}
	if v := c.Query("due_after"); v != "" {
		if t, err := time.Parse(time.RFC3339, v); err == nil {
			filter.DueAfter = &t
		}
	}
	if v := c.Query("page"); v != "" {
		if p, err := strconv.Atoi(v); err == nil && p > 0 {
			filter.Page = p
		}
	}
	if v := c.Query("limit"); v != "" {
		if l, err := strconv.Atoi(v); err == nil && l > 0 {
			filter.Limit = l
		}
	}

	tasks, err := h.Service.FilterWithRelations(filter)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    tasks,
		"page":    filter.Page,
		"limit":   filter.Limit,
	})
}

// =====================
// UPDATE
// =====================
func (h *TaskHandler) Update(c *gin.Context) {
	id := c.Param("id")

	var req dto.UpdateTaskRequest // 👈 Без скобок!
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Invalid request body"})
		return
	}

	// Получаем текущую задачу (простую модель) для обновления полей
	current, err := h.Service.Get(id)
	if err != nil {
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "Task not found"})
			return
		}
		utils.Error(c, http.StatusInternalServerError, err)
		return
	}

	// Обновляем только переданные поля (partial update)
	if req.Title != nil {
		current.Title = *req.Title
	}
	if req.Description != nil {
		current.Description = req.Description
	}
	if req.StatusID != nil {
		current.StatusID = *req.StatusID
	}
	if req.PriorityID != nil {
		current.PriorityID = *req.PriorityID
	}
	if req.DueDate != nil {
		if *req.DueDate == "" {
			// Если пустая строка - очищаем дату
			current.DueDate = nil
		} else {
			// Парсим RFC3339 строку в time.Time
			parsed, err := time.Parse(time.RFC3339, *req.DueDate)
			if err != nil {
				c.JSON(http.StatusBadRequest, gin.H{
					"success": false,
					"error":   "Invalid due_date format. Use RFC3339 (e.g., 2026-03-31T23:59:59Z)",
				})
				return
			}
			current.DueDate = &parsed
		}
	}
	if req.IsCompleted != nil {
		current.IsCompleted = *req.IsCompleted
		// Авто-заполнение completed_at при завершении
		if *req.IsCompleted && current.CompletedAt == nil {
			now := time.Now()
			current.CompletedAt = &now
		}
		// Если снимаем галочку - очищаем completed_at
		if !*req.IsCompleted {
			current.CompletedAt = nil
		}
	}

	if err := h.Service.Update(current); err != nil {
		utils.Error(c, http.StatusBadRequest, err)
		return
	}

	// Возвращаем обновлённую задачу с relations
	updated, err := h.Service.GetWithRelations(id)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"success": true, "message": "Updated"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": updated})
}

// =====================
// DELETE
// =====================
func (h *TaskHandler) Delete(c *gin.Context) {
	id := c.Param("id")

	if err := h.Service.Delete(id); err != nil {
		utils.Error(c, http.StatusInternalServerError, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true})
}