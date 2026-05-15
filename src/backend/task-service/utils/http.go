package utils

import (
	"log"
	"time"
	"github.com/gin-gonic/gin"
)

func Error(c *gin.Context, status int, err error) {

	// лог в консоль сервера
	log.Println("ERROR:", err)

	c.JSON(status, gin.H{
		"success": false,
		"error": gin.H{
			"message": err.Error(),
		},
	})
}


// ParseRFC3339String парсит строку RFC3339 в *time.Time
func ParseRFC3339String(dateStr *string) (*time.Time, error) {
	if dateStr == nil || *dateStr == "" {
		return nil, nil
	}
	
	t, err := time.Parse(time.RFC3339, *dateStr)
	if err != nil {
		return nil, err
	}
	
	return &t, nil
}