/*
 Optional content-based deduplication for S3 Storage Service.
 Stub implementation. Content-based dedup (SHA-256) deferred.
storage_key uniqueness is already enforced by DB UNIQUE constraint.
 */

#pragma once

#include <cstdint>
#include <functional>
#include <string>

namespace s3 {
class DedupService {
public:
    static DedupService& instance();
    void deduplicateBucket(
        const std::string& bucketId,
        const std::string& userId,
        std::function<void(int removedCount, int64_t removedSize)> successCb,
        std::function<void(const std::exception&)> exceptCb,
        const std::string& requestId = {});
    void checkStorageKeyUnique(
        const std::string& storageKey,
        std::function<void(bool)> successCb,
        std::function<void(const std::exception&)> exceptCb);

    DedupService(const DedupService&) = delete;
    DedupService& operator=(const DedupService&) = delete;

private:
    DedupService() = default;
};

}

