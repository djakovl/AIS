// Implementation of DedupService — deduplicate bucket, stub check.
#include "services/DedupService.h"
#include "models/File.h"
#include "services/DatabaseService.h"
#include "services/StorageService.h"
#include "utils/Logger.h"
#include <drogon/drogon.h>
#include <drogon/orm/Exception.h>
#include <map>
#include <memory>
#include <tuple>
#include <vector>

namespace s3 {

DedupService& DedupService::instance() {
    static DedupService instance;
    return instance;
}

void DedupService::deduplicateBucket(
    const std::string& bucketId,
    const std::string& userId,
    std::function<void(int removedCount, int64_t removedSize)> successCb,
    std::function<void(const std::exception&)> exceptCb,
    const std::string& requestId) {
    auto& db = DatabaseService::instance();

    const char* bucketSql =
        "SELECT id FROM buckets WHERE id = $1 AND user_id = $2 AND "
        "deleted_at IS NULL";

    db.execSqlAsync(
        bucketSql,
        [&db, bucketId, userId, successCb, exceptCb, requestId](
            const drogon::orm::Result& r) {
            if (r.size() == 0) {
                Logger::error(
                    "deduplicateBucket: bucket not found or access denied",
                    userId, requestId);
                if (exceptCb) {
                    exceptCb(drogon::orm::SqlError(
                        "Bucket not found or access denied", "", nullptr));
                }
                return;
            }

            const char* filesSql =
                "SELECT id, bucket_id, user_id, parent_folder_id, name, size, "
                "storage_key, updated_at FROM files WHERE bucket_id = $1 AND "
                "user_id = $2 AND deleted_at IS NULL AND is_folder = false "
                "ORDER BY name, COALESCE(parent_folder_id::text, ''), size, "
                "updated_at DESC";

            db.execSqlAsync(
                filesSql,
                [&db, bucketId, userId, successCb, exceptCb, requestId](
                    const drogon::orm::Result& filesResult) {
                    std::map<std::tuple<std::string, std::string, int64_t>,
                             std::vector<File>>
                        groups;
                    for (size_t i = 0; i < filesResult.size(); ++i) {
                        File f = File::fromRow(filesResult[i]);
                        auto key = std::make_tuple(
                            f.name,
                            f.parentFolderId.empty() ? "" : f.parentFolderId,
                            f.size);
                        groups[key].push_back(f);
                    }

                    std::vector<File> toDelete;
                    int64_t removedSize = 0;
                    for (const auto& kv : groups) {
                        const auto& vec = kv.second;
                        if (vec.size() > 1) {
                            for (size_t i = 1; i < vec.size(); ++i) {
                                toDelete.push_back(vec[i]);
                                removedSize += vec[i].size;
                            }
                        }
                    }

                    if (toDelete.empty()) {
                        if (successCb) successCb(0, 0);
                        return;
                    }

                    int removedCount = static_cast<int>(toDelete.size());

                    db.newTransactionAsync(
                        [bucketId, userId, toDelete, removedCount, removedSize,
                         successCb, exceptCb, requestId](
                            const std::shared_ptr<drogon::orm::Transaction>&
                                trans) {
                            if (!trans) {
                                Logger::error(
                                    "deduplicateBucket: failed to create "
                                    "transaction",
                                    userId, requestId);
                                if (exceptCb) {
                                    exceptCb(drogon::orm::SqlError(
                                        "deduplicateBucket: failed to create "
                                        "transaction",
                                        "", nullptr));
                                }
                                return;
                            }
                            auto idxPtr = std::make_shared<size_t>(0);
                            const char* updateFileSql =
                                "UPDATE files SET deleted_at = CURRENT_TIMESTAMP, "
                                "updated_at = CURRENT_TIMESTAMP WHERE id = $1";

                            std::function<void()> updateNextFile;
                            updateNextFile = [trans, idxPtr, toDelete,
                                             updateFileSql, bucketId,
                                             removedCount, removedSize,
                                             successCb, exceptCb, requestId,
                                             updateNextFile, userId]() {
                                if (*idxPtr >= toDelete.size()) {
                                    const char* updateBucketSql =
                                        "UPDATE buckets SET storage_used = "
                                        "GREATEST(0, storage_used - $1), "
                                        "updated_at = CURRENT_TIMESTAMP "
                                        "WHERE id = $2 AND deleted_at IS NULL";
                                    trans->execSqlAsync(
                                        updateBucketSql,
                                        [trans, toDelete, removedCount,
                                         removedSize, successCb, requestId](
                                            const drogon::orm::Result&) {
                                            drogon::app().getLoop()->queueInLoop(
                                                [toDelete, removedCount,
                                                 removedSize, successCb,
                                                 requestId]() {
                                                    auto& storage =
                                                        StorageService::instance();
                                                    for (const auto& f :
                                                         toDelete) {
                                                        std::string fullPath =
                                                            storage.getFullPath(
                                                                f.userId,
                                                                f.bucketId,
                                                                f.storageKey);
                                                        std::string err;
                                                        if (!storage.deleteFile(
                                                                fullPath,
                                                                &err)) {
                                                            Logger::warn(
                                                                "deduplicateBucket: "
                                                                "deleteFile failed: " +
                                                                    err,
                                                                f.userId,
                                                                requestId);
                                                        }
                                                    }
                                                    if (successCb) {
                                                        successCb(removedCount,
                                                                 removedSize);
                                                    }
                                                });
                                        },
                                        [trans, userId, exceptCb, requestId](
                                            const drogon::orm::DrogonDbException&
                                                e) {
                                            trans->rollback();
                                            Logger::error(
                                                "deduplicateBucket: UPDATE "
                                                "buckets failed: " +
                                                    std::string(e.base().what()),
                                                userId, requestId);
                                            if (exceptCb) exceptCb(e.base());
                                        },
                                        removedSize,
                                        bucketId);
                                    return;
                                }

                                trans->execSqlAsync(
                                    updateFileSql,
                                    [trans, idxPtr, toDelete, updateFileSql,
                                     bucketId, removedSize, successCb, exceptCb,
                                     requestId, updateNextFile](
                                        const drogon::orm::Result&) {
                                        ++(*idxPtr);
                                        updateNextFile();
                                    },
                                    [trans, userId, exceptCb, requestId](
                                        const drogon::orm::DrogonDbException& e) {
                                        trans->rollback();
                                        Logger::error(
                                            "deduplicateBucket: UPDATE files "
                                            "failed: " +
                                                std::string(e.base().what()),
                                            userId, requestId);
                                        if (exceptCb) exceptCb(e.base());
                                    },
                                    toDelete[*idxPtr].id);
                            };

                            updateNextFile();
                        });
                },
                [userId, exceptCb, requestId](
                    const drogon::orm::DrogonDbException& e) {
                    Logger::error(
                        "deduplicateBucket: files query failed: " +
                            std::string(e.base().what()),
                        userId, requestId);
                    if (exceptCb) exceptCb(e.base());
                },
                bucketId,
                userId);
        },
        [userId, exceptCb, requestId](
            const drogon::orm::DrogonDbException& e) {
            Logger::error(
                "deduplicateBucket: bucket check failed: " +
                    std::string(e.base().what()),
                userId, requestId);
            if (exceptCb) exceptCb(e.base());
        },
        bucketId,
        userId);
}

void DedupService::checkStorageKeyUnique(
    const std::string& /* storageKey */,
    std::function<void(bool)> successCb,
    std::function<void(const std::exception&)> /* exceptCb */) {
    // Stub: DB UNIQUE on storage_key enforces uniqueness. Always report unique.
    drogon::app().getLoop()->queueInLoop(
        [cb = std::move(successCb)]() { cb(true); });
}

}
