// handlers/reference_handler.go
package handlers

import (
	"database/sql"
	"log"
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
	log.Printf("DEBUG ListStatuses: Path='%s', Headers=%v", c.Request.URL.Path, c.Request.Header)
	rows, err := h.DB.Query("SELECT id, name FROM tasks.statuses ORDER BY id")
	if err != nil {
		log.Printf("ERROR ListStatuses query: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()

	var statuses []models.Status
	for rows.Next() {
		var s models.Status
		if err := rows.Scan(&s.ID, &s.Name); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		statuses = append(statuses, s)
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": statuses})
}

// GET /priorities
func (h *ReferenceHandler) ListPriorities(c *gin.Context) {
	log.Printf("DEBUG ListPriorities: Path='%s', Headers=%v", c.Request.URL.Path, c.Request.Header)
	rows, err := h.DB.Query("SELECT id, name, level FROM tasks.priorities ORDER BY level")
	if err != nil {
		log.Printf("ERROR ListPriorities query: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()

	var priorities []models.Priority
	for rows.Next() {
		var p models.Priority
		if err := rows.Scan(&p.ID, &p.Name, &p.Level); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		priorities = append(priorities, p)
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": priorities})
}