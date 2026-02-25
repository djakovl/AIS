/*
 Periodic cleanup of soft-deleted records and physical files.
 Cleans buckets and files WHERE deleted_at IS NOT NULL AND deleted_at <
 NOW() - 7 days. For files: deletes physical file via StorageService, then hard-deletes from DB. 
For buckets: hard-deletes only if no files remain.
 */
#pragma once

#include <functional>

namespace s3 {
/*
Cleanup of soft-deleted records older than retention period.
Uses DatabaseService, StorageService. Runs async to avoid blocking event loop. Can be invoked from a timer (e.g. runEvery).
 */
class CleanupService {
public:
    static CleanupService& instance();

    /*
Clean up soft-deleted files and buckets older than 7 days.
 1. Select files WHERE deleted_at IS NOT NULL AND deleted_at < NOW() - INTERVAL '7 days'
 2. For each file (non-folder): delete physical file, then hard-delete from DB
  3. For each folder: hard-delete from DB only
  4. Select buckets WHERE deleted_at IS NOT NULL AND deleted_at <NOW() - INTERVAL '7 days'
  5. For each bucket: if no files remain, hard-delete from DB Callable from a timer (e.g. runEvery)
 doneCb Optional callback when cleanup completes
     */
    void cleanupFilesWithDeletedMark(std::function<void()> doneCb = {});

    CleanupService(const CleanupService&) = delete;
    CleanupService& operator=(const CleanupService&) = delete;

private:
    CleanupService() = default;

    void cleanupBuckets(std::function<void()> doneCb);
};

}  // namespace s3
