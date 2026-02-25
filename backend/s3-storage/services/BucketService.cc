#include "services/BucketService.h"
#include "models/Bucket.h"
#include "services/DatabaseService.h"
#include "services/StorageService.h"
#include "utils/Logger.h"
#include "utils/UUIDGenerator.h"
#include <drogon/orm/Exception.h>

namespace s3 {

namespace {

constexpr int64_t DEFAULT_STORAGE_LIMIT = 10737418240LL;  // 10GB

}  // namespace

BucketService& BucketService::instance() {
    static BucketService instance;
    return instance;
}

// Создание бакета: сначала директория на диске, затем INSERT в БД; при ошибке — откат
void BucketService::createBucket(
    const std::string& userId,
    const std::string& name,
    const std::string& description,
    bool isPublic,
    std::function<void(const Bucket&)> successCb,
    std::function<void(const drogon::orm::DrogonDbException&)> exceptCb) {
    const std::string bucketId = UUIDGenerator::generateUUID();

    // Порядок: сначала диск, потом БД. При откате — удаляем директорию.
    auto& storage = StorageService::instance();
    std::string bucketPath = storage.getBucketPath(userId, bucketId);
    if (!storage.ensureDirectory(bucketPath)) {
        Logger::error("createBucket: failed to create directory " + bucketPath,
                      userId, "");
        exceptCb(drogon::orm::SqlError(
            "createBucket: failed to create bucket directory", "", nullptr));
        return;
    }

    auto& db = DatabaseService::instance();
    const char* sql =
        "INSERT INTO buckets (id, user_id, name, description, is_public, "
        "storage_limit) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *";

    db.execSqlAsync(
        sql,
        [bucketId, userId, bucketPath, successCb, exceptCb](
            const drogon::orm::Result& r) {
            if (r.size() == 0) {
                Logger::error("createBucket: INSERT returned no rows", userId,
                              "");
                StorageService::instance().removeDirectory(bucketPath);
                exceptCb(drogon::orm::SqlError(
                    "createBucket: INSERT returned no rows", "", nullptr));
                return;
            }
            successCb(Bucket::fromRow(r[0]));
        },
        [bucketPath, exceptCb](const drogon::orm::DrogonDbException& e) {
            StorageService::instance().removeDirectory(bucketPath);
            exceptCb(e);
        },
        bucketId,
        userId,
        name,
        description,
        isPublic,
        DEFAULT_STORAGE_LIMIT);
}

// Список бакетов пользователя (только не удалённые: deleted_at IS NULL)
void BucketService::listBuckets(
    const std::string& userId,
    std::function<void(const std::vector<Bucket>&)> successCb,
    std::function<void(const drogon::orm::DrogonDbException&)> exceptCb) {
    auto& db = DatabaseService::instance();
    const char* sql =
        "SELECT * FROM buckets WHERE user_id = $1 AND deleted_at IS NULL "
        "ORDER BY created_at DESC";

    db.execSqlAsync(
        sql,
        [successCb](const drogon::orm::Result& r) {
            std::vector<Bucket> buckets;
            buckets.reserve(r.size());
            for (size_t i = 0; i < r.size(); ++i) {
                buckets.push_back(Bucket::fromRow(r[i]));
            }
            successCb(buckets);
        },
        exceptCb,
        userId);
}

void BucketService::checkQuota(
    const std::string& bucketId,
    int64_t additionalSize,
    std::function<void(QuotaCheckResult)> successCb,
    std::function<void(const drogon::orm::DrogonDbException&)> exceptCb) {
    auto& db = DatabaseService::instance();
    const char* sql =
        "SELECT storage_used, storage_limit FROM buckets WHERE id = $1 AND "
        "deleted_at IS NULL";

    db.execSqlAsync(
        sql,
        [additionalSize, successCb](const drogon::orm::Result& r) {
            if (r.size() == 0) {
                successCb(QuotaCheckResult::NOT_FOUND);
                return;
            }
            int64_t used = r[0]["storage_used"].as<long long>();
            int64_t limit = r[0]["storage_limit"].as<long long>();
            successCb(used + additionalSize <= limit ? QuotaCheckResult::OK
                                                     : QuotaCheckResult::QUOTA_EXCEEDED);
        },
        exceptCb,
        bucketId);
}

void BucketService::deleteBucket(
    const std::string& bucketId,
    const std::string& userId,
    std::function<void(const Bucket&)> successCb,
    std::function<void(const drogon::orm::DrogonDbException&)> exceptCb,
    const std::string& requestId) {
    auto& db = DatabaseService::instance();

    db.newTransactionAsync(
        [bucketId, userId, successCb, exceptCb, requestId](
            const std::shared_ptr<drogon::orm::Transaction>& trans) {
            const char* selectBucketSql =
                "SELECT * FROM buckets WHERE id = $1 AND user_id = $2 AND "
                "deleted_at IS NULL FOR UPDATE";
            trans->execSqlAsync(
                selectBucketSql,
                [trans, bucketId, userId, successCb, exceptCb, requestId](
                    const drogon::orm::Result& r) {
                    if (r.size() == 0) {
                        Logger::error(
                            "deleteBucket: bucket not found or access denied",
                            userId, requestId);
                        trans->rollback();
                        if (exceptCb) {
                            exceptCb(drogon::orm::SqlError(
                                "Bucket not found or access denied", "", nullptr));
                        }
                        return;
                    }

                    const char* countFilesSql =
                        "SELECT COUNT(*) AS cnt FROM files WHERE bucket_id = $1 "
                        "AND deleted_at IS NULL";
                    trans->execSqlAsync(
                        countFilesSql,
                        [trans, bucketId, userId, successCb, exceptCb, requestId](
                            const drogon::orm::Result& countResult) {
                            int64_t fileCount =
                                countResult[0]["cnt"].as<int64_t>();
                            if (fileCount > 0) {
                                Logger::error(
                                    "deleteBucket: bucket is not empty",
                                    userId, requestId);
                                trans->rollback();
                                if (exceptCb) {
                                    exceptCb(drogon::orm::SqlError(
                                        "Bucket is not empty", "", nullptr));
                                }
                                return;
                            }

                            const char* updateSql =
                                "UPDATE buckets SET deleted_at = CURRENT_TIMESTAMP, "
                                "updated_at = CURRENT_TIMESTAMP WHERE id = $1 AND "
                                "user_id = $2 AND deleted_at IS NULL RETURNING *";
                            trans->execSqlAsync(
                                updateSql,
                                [successCb, exceptCb, trans, userId, requestId](
                                    const drogon::orm::Result& r) {
                                    if (r.size() == 0) {
                                        Logger::error(
                                            "deleteBucket: UPDATE affected no rows",
                                            userId, requestId);
                                        trans->rollback();
                                        if (exceptCb) {
                                            exceptCb(drogon::orm::SqlError(
                                                "deleteBucket: update failed", "", nullptr));
                                        }
                                        return;
                                    }
                                    if (successCb) {
                                        successCb(Bucket::fromRow(r[0]));
                                    }
                                },
                                [trans, userId, exceptCb, requestId](
                                    const drogon::orm::DrogonDbException& e) {
                                    trans->rollback();
                                    Logger::error(
                                        "deleteBucket: UPDATE failed: " +
                                            std::string(e.base().what()),
                                        userId, requestId);
                                    if (exceptCb) exceptCb(e);
                                },
                                bucketId,
                                userId);
                        },
                        [trans, userId, exceptCb, requestId](
                            const drogon::orm::DrogonDbException& e) {
                            trans->rollback();
                            Logger::error(
                                "deleteBucket: COUNT files failed: " +
                                    std::string(e.base().what()),
                                userId, requestId);
                            if (exceptCb) exceptCb(e);
                        },
                        bucketId);
                },
                [trans, userId, exceptCb, requestId](
                    const drogon::orm::DrogonDbException& e) {
                    trans->rollback();
                    Logger::error(
                        "deleteBucket: SELECT bucket failed: " +
                            std::string(e.base().what()),
                        userId, requestId);
                    if (exceptCb) exceptCb(e);
                },
                bucketId,
                userId);
        });
}

}
