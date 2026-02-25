// handlers/reference_handler.go
package handlers

import (
	"database/sql"
	"net/http"
	"github.com/gin-gonic/gin"
	"task-service/models"
)

type ReferenceHandler struct {
	DB *sql.DB
}

func NewReferenceHandler(db *sql.DB) *ReferenceHandler {
	return &ReferenceHandler{DB: db}
}

// GET /statuses
func (h *ReferenceHandler) ListStatuses(c *gin.Context) {
	rows, err := h.DB.Query("SELECT id, name, color, order_index FROM statuses ORDER BY order_index")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()

	var statuses []models.Status
	for rows.Next() {
		var s models.Status
		if err := rows.Scan(&s.ID, &s.Name, &s.Color, &s.OrderIndex); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		statuses = append(statuses, s)
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": statuses})
}

// GET /priorities
func (h *ReferenceHandler) ListPriorities(c *gin.Context) {
	rows, err := h.DB.Query("SELECT id, name, color, eisenhower_quad, order_index FROM priorities ORDER BY order_index")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()

	var priorities []models.Priority
	for rows.Next() {
		var p models.Priority
		if err := rows.Scan(&p.ID, &p.Name, &p.Color, &p.EisenhowerQuad, &p.OrderIndex); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		priorities = append(priorities, p)
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": priorities})
}