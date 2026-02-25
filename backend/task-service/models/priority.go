package models

import "time"

type Priority struct {
	ID              string    `json:"id"`
	Name            string    `json:"name"`
	Color           string    `json:"color"`
	EisenhowerQuad  int       `json:"eisenhower_quad"`
	OrderIndex      int       `json:"order_index"`
	IsDefault       bool      `json:"is_default"`
	CreatedAt       time.Time `json:"created_at"`
}