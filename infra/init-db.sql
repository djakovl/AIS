-- Создание схем для каждого сервиса
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS tasks;
CREATE SCHEMA IF NOT EXISTS storage;

-- Расширения
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Таблицы Auth Service
CREATE TABLE IF NOT EXISTS auth.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    roles TEXT[] DEFAULT ARRAY['user']::TEXT[],
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_users_email ON auth.users(email);
CREATE INDEX idx_users_username ON auth.users(username);

-- Таблицы Task Service
CREATE TABLE IF NOT EXISTS tasks.statuses (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL
);

INSERT INTO tasks.statuses (name) VALUES
    ('pending'), ('in_progress'), ('completed'), ('cancelled')
ON CONFLICT (name) DO NOTHING;

CREATE TABLE IF NOT EXISTS tasks.priorities (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    level INT UNIQUE NOT NULL
);

INSERT INTO tasks.priorities (name, level) VALUES
    ('low', 1), ('medium', 2), ('high', 3), ('urgent', 4)
ON CONFLICT (name) DO NOTHING;

CREATE TABLE IF NOT EXISTS tasks.tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status_id INT REFERENCES tasks.statuses(id) DEFAULT 1,
    priority_id INT REFERENCES tasks.priorities(id) DEFAULT 2,
    due_date TIMESTAMP,
    tags TEXT[],
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_tasks_user_id ON tasks.tasks(user_id);
CREATE INDEX idx_tasks_status ON tasks.tasks(status_id);
CREATE INDEX idx_tasks_priority ON tasks.tasks(priority_id);
CREATE INDEX idx_tasks_due_date ON tasks.tasks(due_date);

-- Таблицы S3 Service
CREATE TABLE IF NOT EXISTS storage.buckets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    s3_bucket_name VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_buckets_user_id ON storage.buckets(user_id);

CREATE TABLE IF NOT EXISTS storage.files (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    bucket_id UUID REFERENCES storage.buckets(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    filename VARCHAR(500) NOT NULL,
    s3_key VARCHAR(1000) NOT NULL,
    size_bytes BIGINT NOT NULL,
    mime_type VARCHAR(255),
    is_public BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_files_bucket_id ON storage.files(bucket_id);
CREATE INDEX idx_files_user_id ON storage.files(user_id);

CREATE TABLE IF NOT EXISTS storage.shared_links (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    file_id UUID REFERENCES storage.files(id) ON DELETE CASCADE,
    token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_shared_links_token ON storage.shared_links(token);
CREATE INDEX idx_shared_links_file_id ON storage.shared_links(file_id);
