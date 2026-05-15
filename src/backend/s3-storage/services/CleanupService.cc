// Implementation of CleanupService — periodic cleanup of soft-deleted records.
#include "services/CleanupService.h"
#include "services/DatabaseService.h"
#include "services/StorageService.h"
#include "utils/Logger.h"
#include <drogon/drogon.h>
#include <drogon/orm/DbClient.h>
#include <drogon/orm/Field.h>

namespace s3 {

CleanupService& CleanupService::instance() {
    static CleanupService instance;
    return instance;
}

void CleanupService::cleanupFilesWithDeletedMark(std::function<void()> doneCb) {
    auto& db = DatabaseService::instance();
    auto& storage = StorageService::instance();

    const std::string selectFiles =
        "SELECT id, user_id, bucket_id, storage_key, is_folder FROM files "
        "WHERE deleted_at IS NOT NULL AND deleted_at < NOW() - INTERVAL '7 days'";

    auto fileErrorCb = doneCb;
    db.execSqlAsync(
        selectFiles,
        [&storage, doneCb = std::move(doneCb)](
            const drogon::orm::Result& filesResult) {
            std::vector<std::string> fileIds;
            for (const auto& row : filesResult) {
                std::string id = row["id"].as<std::string>();
                std::string userId = row["user_id"].as<std::string>();
                std::string bucketId = row["bucket_id"].as<std::string>();
                std::string storageKey = row["storage_key"].as<std::string>();
                bool isFolder = row["is_folder"].as<bool>();

                if (!isFolder && !storageKey.empty()) {
                    std::string fullPath =
                        storage.getFullPath(userId, bucketId, storageKey);
                    storage.deleteFile(fullPath);
                }
                fileIds.push_back(id);
            }

            if (fileIds.empty()) {
                CleanupService::instance().cleanupBuckets(std::move(doneCb));
                return;
            }

            auto& db2 = DatabaseService::instance();
            auto remaining = std::make_shared<size_t>(fileIds.size());
            auto cb = std::move(doneCb);

            for (const auto& fileId : fileIds) {
                db2.execSqlAsync(
                    "DELETE FROM files WHERE id = $1",
                    [remaining, cb](const drogon::orm::Result&) {
                        if (--(*remaining) == 0) {
                            CleanupService::instance().cleanupBuckets(
                                std::move(cb));
                        }
                    },
                    [remaining, cb](const drogon::orm::DrogonDbException& e) {
                        Logger::warn("Cleanup: failed to delete file record: " +
                                         std::string(e.base().what()),
                                     "", "");
                        if (--(*remaining) == 0) {
                            CleanupService::instance().cleanupBuckets(
                                std::move(cb));
                        }
                    },
                    fileId);
            }
        },
        [fileErrorCb](const drogon::orm::DrogonDbException& e) {
            Logger::error("Cleanup: failed to select soft-deleted files: " +
                              std::string(e.base().what()),
                          "", "");
            if (fileErrorCb) {
                fileErrorCb();
            }
        });
}

void CleanupService::cleanupBuckets(std::function<void()> doneCb) {
    auto& db = DatabaseService::instance();

    const std::string selectBuckets =
        "SELECT id FROM buckets "
        "WHERE deleted_at IS NOT NULL AND deleted_at < NOW() - INTERVAL '7 days'";

    auto errorCb = doneCb;
    db.execSqlAsync(
        selectBuckets,
        [doneCb = std::move(doneCb)](
            const drogon::orm::Result& bucketsResult) {
            std::vector<std::string> bucketIds;
            for (const auto& row : bucketsResult) {
                bucketIds.push_back(row["id"].as<std::string>());
            }

            if (bucketIds.empty()) {
                if (doneCb) {
                    doneCb();
                }
                return;
            }

            struct State {
                size_t remaining;
                std::function<void()> cb;
                std::vector<std::string> ids;
            };
            auto state = std::make_shared<State>(
                State{bucketIds.size(), std::move(doneCb), std::move(bucketIds)});

            for (const auto& bucketId : state->ids) {
                DatabaseService::instance().execSqlAsync(
                    "SELECT COUNT(*) FROM files WHERE bucket_id = $1",
                    [state, bucketId](
                        const drogon::orm::Result& countResult) {
                        int64_t n = countResult[0][0].as<int64_t>();
                        if (n == 0) {
                            DatabaseService::instance().execSqlAsync(
                                "DELETE FROM buckets WHERE id = $1",
                                [state](const drogon::orm::Result&) {
                                    if (--state->remaining == 0 &&
                                        state->cb) {
                                        state->cb();
                                    }
                                },
                                [state](const drogon::orm::DrogonDbException&) {
                                    if (--state->remaining == 0 &&
                                        state->cb) {
                                        state->cb();
                                    }
                                },
                                bucketId);
                        } else {
                            if (--state->remaining == 0 && state->cb) {
                                state->cb();
                            }
                        }
                    },
                    [state, bucketId](const drogon::orm::DrogonDbException&) {
                        if (--state->remaining == 0 && state->cb) {
                            state->cb();
                        }
                    },
                    bucketId);
            }
        },
        [errorCb](const drogon::orm::DrogonDbException& e) {
            Logger::error("Cleanup: failed to select soft-deleted buckets: " +
                              std::string(e.base().what()),
                          "", "");
            if (errorCb) {
                errorCb();
            }
        });
}

}
