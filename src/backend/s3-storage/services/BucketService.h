/*
 Bucket business logic: create, list, quota check.
 Секретарь — bucket operations for POST /files/buckets/create and GET/files/buckets/list.
 */

#pragma once

#include "models/Bucket.h"
#include <drogon/orm/Exception.h>
#include <functional>
#include <string>
#include <vector>

namespace s3 {

 // Result of a quota check.
enum class QuotaCheckResult {
    OK,             ///< Bucket exists and has sufficient quota
    NOT_FOUND,      ///< Bucket does not exist or is deleted
    QUOTA_EXCEEDED  ///< Bucket exists but used + additionalSize > limit
};

/*
 Bucket operations: create, list, check quota.
 Uses DatabaseService, UUIDGenerator, StorageService. All SELECT includes
 WHERE deleted_at IS NULL.
 */
class BucketService {
public:
    // Get singleton instance.
    static BucketService& instance();

    void createBucket(const std::string& userId,
                      const std::string& name,
                      const std::string& description,
                      bool isPublic,
                      std::function<void(const Bucket&)> successCb,
                      std::function<void(const drogon::orm::DrogonDbException&)>
                          exceptCb);

    void listBuckets(
        const std::string& userId,
        std::function<void(const std::vector<Bucket>&)> successCb,
        std::function<void(const drogon::orm::DrogonDbException&)> exceptCb);

    /*
     Check if bucket has quota for additional size.
     successCb receives: OK (quota available), NOT_FOUND (bucket missing), or QUOTA_EXCEEDED (used + additionalSize > limit).
     */
    void checkQuota(
        const std::string& bucketId,
        int64_t additionalSize,
        std::function<void(QuotaCheckResult)> successCb,
        std::function<void(const drogon::orm::DrogonDbException&)> exceptCb);

    void deleteBucket(
        const std::string& bucketId,
        const std::string& userId,
        std::function<void(const Bucket&)> successCb,
        std::function<void(const drogon::orm::DrogonDbException&)> exceptCb,
        const std::string& requestId = {});

    BucketService(const BucketService&) = delete;
    BucketService& operator=(const BucketService&) = delete;

private:
    BucketService() = default;
};

}  // namespace s3
