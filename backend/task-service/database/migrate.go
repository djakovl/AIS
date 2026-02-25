package database

import "database/sql"

func RunMigrations(db *sql.DB) error {

	query := `
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =========================
-- STATUSES
-- =========================
CREATE TABLE IF NOT EXISTS statuses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) NOT NULL,
    color VARCHAR(7) NOT NULL,
    order_index INTEGER NOT NULL,
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =========================
-- PRIORITIES
-- =========================
CREATE TABLE IF NOT EXISTS priorities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) NOT NULL,
    color VARCHAR(7) NOT NULL,
    eisenhower_quad INTEGER CHECK (eisenhower_quad BETWEEN 1 AND 4),
    order_index INTEGER NOT NULL,
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =========================
-- TASKS
-- =========================
CREATE TABLE IF NOT EXISTS tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    parent_task_id UUID NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT NULL,
    status_id UUID NOT NULL,
    priority_id UUID NOT NULL,
    due_date TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,
    is_completed BOOLEAN DEFAULT false,
    order_index INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_parent_task
        FOREIGN KEY(parent_task_id)
        REFERENCES tasks(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_status
        FOREIGN KEY(status_id)
        REFERENCES statuses(id),

    CONSTRAINT fk_priority
        FOREIGN KEY(priority_id)
        REFERENCES priorities(id)
);
`

	_, err := db.Exec(query)
	return err
}