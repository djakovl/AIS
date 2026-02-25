-- S3 Storage Service - Initial migration
-- PostgreSQL 15+
-- Soft delete: all SELECT on buckets/files must use WHERE deleted_at IS NULL
-- gen_random_uuid() is built-in since PostgreSQL 13

-- =============================================================================
-- buckets
-- =============================================================================
CREATE TABLE buckets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    is_public BOOLEAN DEFAULT FALSE,
    storage_used BIGINT DEFAULT 0,
    storage_limit BIGINT DEFAULT 10737418240,  -- 10GB
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL
);

CREATE INDEX idx_buckets_user_id ON buckets(user_id);
CREATE INDEX idx_buckets_deleted_at ON buckets(deleted_at) WHERE deleted_at IS NOT NULL;

-- =============================================================================
-- files
-- =============================================================================
CREATE TABLE files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bucket_id UUID NOT NULL REFERENCES buckets(id),
    user_id UUID NOT NULL,
    parent_folder_id UUID NULL REFERENCES files(id),
    name VARCHAR(255) NOT NULL,
    path TEXT NOT NULL,
    size BIGINT DEFAULT 0,
    mime_type VARCHAR(100) DEFAULT 'application/octet-stream',
    storage_key TEXT NOT NULL UNIQUE,
    is_folder BOOLEAN DEFAULT FALSE,
    is_public BOOLEAN DEFAULT FALSE,
    download_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL
);

CREATE INDEX idx_files_bucket_id ON files(bucket_id);
CREATE INDEX idx_files_user_id ON files(user_id);
CREATE INDEX idx_files_parent_folder_id ON files(parent_folder_id);
CREATE INDEX idx_files_deleted_at ON files(deleted_at) WHERE deleted_at IS NOT NULL;
-- storage_key: UNIQUE constraint creates index automatically

-- =============================================================================
-- shared_links (no soft delete - use is_active for revocation)
-- =============================================================================
CREATE TABLE shared_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_id UUID NOT NULL REFERENCES files(id),
    user_id UUID NOT NULL,
    token VARCHAR(64) NOT NULL UNIQUE,
    expires_at TIMESTAMP NULL,
    max_downloads INTEGER NULL,
    download_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_shared_links_file_id ON shared_links(file_id);
CREATE INDEX idx_shared_links_user_id ON shared_links(user_id);
-- token: UNIQUE constraint already creates an index
