
// Implementation of FileService — folders, list, move.

#include "services/FileService.h"
#include "models/File.h"
#include "services/BucketService.h"
#include "services/DatabaseService.h"
#include "services/StorageService.h"
#include "utils/Logger.h"
#include "utils/UUIDGenerator.h"
#include <drogon/orm/Exception.h>
#include <optional>

namespace s3 {

FileService& FileService::instance() {
    static FileService instance;
    return instance;
}

void FileService::createFolder(
    const std::string& bucketId,
    const std::string& userId,
    const std::string& parentFolderId,
    const std::string& name,
    std::function<void(const File&)> successCb,
    std::function<void(const drogon::orm::DrogonDbException&)> exceptCb) {
    auto& db = DatabaseService::instance();

    auto doInsert = [&db, bucketId, userId, name, successCb, exceptCb](
                        const std::string& parentPath,
                        const std::string& folderId,
                        const std::string& parentIdForDb) {
        std::string path = parentPath.empty() ? name + "/" : parentPath + name + "/";
        std::string storageKey = folderId;

        auto onResult = [successCb, exceptCb](const drogon::orm::Result& r) {
            if (r.size() == 0) {
                Logger::error("createFolder: INSERT returned no rows", "", "");
                exceptCb(drogon::orm::SqlError(
                    "createFolder: INSERT returned no rows", "", nullptr));
                return;
            }
            successCb(File::fromRow(r[0]));
        };

        if (parentIdForDb.empty()) {
            const char* sql =
                "INSERT INTO files (id, bucket_id, user_id, name, path, size, "
                "mime_type, storage_key, is_folder) VALUES ($1, $2, $3, $4, $5, "
                "0, '', $6, true) RETURNING *";
            db.execSqlAsync(sql, onResult, exceptCb, folderId, bucketId, userId,
                           name, path, storageKey);
        } else {
            const char* sql =
                "INSERT INTO files (id, bucket_id, user_id, parent_folder_id, name, "
                "path, size, mime_type, storage_key, is_folder) VALUES ($1, $2, "
                "$3, $4, $5, $6, 0, '', $7, true) RETURNING *";
            db.execSqlAsync(sql, onResult, exceptCb, folderId, bucketId, userId,
                           parentIdForDb, name, path, storageKey);
        }
    };

    std::string folderId = UUIDGenerator::generateUUID();

    if (parentFolderId.empty()) {
        doInsert("", folderId, "");
        return;
    }

    const char* parentSql =
        "SELECT path FROM files WHERE id = $1 AND user_id = $2 AND bucket_id = $3 "
        "AND is_folder = true AND deleted_at IS NULL";
    db.execSqlAsync(
        parentSql,
        [doInsert, folderId, parentFolderId, bucketId, userId, name, successCb,
         exceptCb](const drogon::orm::Result& r) {
            if (r.size() == 0) {
                Logger::error("createFolder: parent folder not found", userId, "");
                exceptCb(drogon::orm::SqlError("Parent folder not found", "", nullptr));
                return;
            }
            std::string parentPath = r[0]["path"].as<std::string>();
            doInsert(parentPath, folderId, parentFolderId);
        },
        exceptCb,
        parentFolderId,
        userId,
        bucketId);
}

void FileService::listFiles(
    const std::string& bucketId,
    const std::string& userId,
    const std::string& parentFolderId,
    std::function<void(const std::vector<File>&)> successCb,
    std::function<void(const drogon::orm::DrogonDbException&)> exceptCb) {
    auto& db = DatabaseService::instance();

    if (parentFolderId.empty()) {
        const char* sql =
            "SELECT * FROM files WHERE bucket_id = $1 AND user_id = $2 "
            "AND parent_folder_id IS NULL AND deleted_at IS NULL "
            "ORDER BY is_folder DESC, name ASC";
        db.execSqlAsync(
            sql,
            [successCb](const drogon::orm::Result& r) {
                std::vector<File> files;
                files.reserve(r.size());
                for (size_t i = 0; i < r.size(); ++i) {
                    files.push_back(File::fromRow(r[i]));
                }
                successCb(files);
            },
            exceptCb,
            bucketId,
            userId);
    } else {
        const char* sql =
            "SELECT * FROM files WHERE bucket_id = $1 AND user_id = $2 "
            "AND parent_folder_id = $3 AND deleted_at IS NULL "
            "ORDER BY is_folder DESC, name ASC";
        db.execSqlAsync(
            sql,
            [successCb](const drogon::orm::Result& r) {
                std::vector<File> files;
                files.reserve(r.size());
                for (size_t i = 0; i < r.size(); ++i) {
                    files.push_back(File::fromRow(r[i]));
                }
                successCb(files);
            },
            exceptCb,
            bucketId,
            userId,
            parentFolderId);
    }
}

void FileService::moveFile(
    const std::string& fileId,
    const std::string& userId,
    const std::string& newParentFolderId,
    std::function<void(const File&)> successCb,
    std::function<void(const drogon::orm::DrogonDbException&)> exceptCb,
    std::optional<std::string> newBucketId,
    const std::string& requestId) {
    auto& db = DatabaseService::instance();
    auto& storage = StorageService::instance();
    auto& bucketSvc = BucketService::instance();

    const char* fetchSql =
        "SELECT * FROM files WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL";
    db.execSqlAsync(
        fetchSql,
        [&db, &storage, &bucketSvc, fileId, userId, newParentFolderId,
         newBucketId, requestId, successCb, exceptCb](const drogon::orm::Result& r) {
            if (r.size() == 0) {
                Logger::error("moveFile: file not found or access denied", userId, requestId);
                exceptCb(drogon::orm::SqlError("File not found or access denied", "", nullptr));
                return;
            }
            File f = File::fromRow(r[0]);

            const bool isCrossBucket =
                newBucketId && !newBucketId->empty() && *newBucketId != f.bucketId;

            if (isCrossBucket) {
                if (f.isFolder) {
                    Logger::error("moveFile: folder cross-bucket not supported", userId, requestId);
                    exceptCb(drogon::orm::SqlError(
                        "Folder move between buckets not supported", "", nullptr));
                    return;
                }

                const char* bucketSql =
                    "SELECT 1 FROM buckets WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL";
                db.execSqlAsync(
                    bucketSql,
                    [&db, &storage, &bucketSvc, f, fileId, userId, newParentFolderId,
                     newBucketId, requestId, successCb, exceptCb](const drogon::orm::Result& br) {
                        if (br.size() == 0) {
                            Logger::error("moveFile: destination bucket not found", userId, requestId);
                            exceptCb(drogon::orm::SqlError(
                                "Destination bucket not found", "", nullptr));
                            return;
                        }

                        auto doCrossBucketMove = [=, &db, &storage, &bucketSvc](
                                                    const std::string& newPath) {
                            bucketSvc.checkQuota(
                                *newBucketId,
                                f.size,
                                [&db, &storage, f, fileId, userId, newParentFolderId,
                                 newBucketId, newPath, requestId, successCb, exceptCb](
                                    QuotaCheckResult quotaResult) {
                                    if (quotaResult == QuotaCheckResult::QUOTA_EXCEEDED) {
                                        Logger::error("moveFile: quota exceeded", userId, requestId);
                                        exceptCb(drogon::orm::SqlError(
                                            "Quota exceeded", "", nullptr));
                                        return;
                                    }
                                    if (quotaResult == QuotaCheckResult::NOT_FOUND) {
                                        Logger::error("moveFile: destination bucket not found",
                                                     userId, requestId);
                                        exceptCb(drogon::orm::SqlError(
                                            "Destination bucket not found", "", nullptr));
                                        return;
                                    }

                                    std::string srcPath = storage.getFullPath(
                                        userId, f.bucketId, f.storageKey);
                                    std::string dstPath = storage.getFullPath(
                                        userId, *newBucketId, f.storageKey);

                                    try {
                                        storage.copyFile(srcPath, dstPath);
                                    } catch (const StorageException& e) {
                                        Logger::error("moveFile: copy failed: " +
                                                         std::string(e.what()),
                                                     userId, requestId);
                                        exceptCb(drogon::orm::SqlError(
                                            "Storage error: " + std::string(e.what()),
                                            "", nullptr));
                                        return;
                                    }

                                    std::string parentIdForDb =
                                        newParentFolderId.empty() ? "" : newParentFolderId;

                                    db.newTransactionAsync(
                                        [&storage, f, fileId, userId, newParentFolderId,
                                         newBucketId, newPath, parentIdForDb, srcPath,
                                         dstPath, requestId, successCb, exceptCb](
                                            const std::shared_ptr<drogon::orm::Transaction>&
                                                trans) {
                                            auto onFileUpdateFailed =
                                                [trans, dstPath, exceptCb, userId, requestId](
                                                    const drogon::orm::DrogonDbException& e) {
                                                    trans->rollback();
                                                    StorageService::instance().deleteFile(dstPath);
                                                    Logger::error(
                                                        "moveFile: DB failed: " +
                                                            std::string(e.base().what()),
                                                        userId, requestId);
                                                    exceptCb(e);
                                                };

                                            auto doUpdateBuckets =
                                                [trans, &storage, f, fileId, srcPath,
                                                 dstPath, successCb, exceptCb, userId, requestId](
                                                    const drogon::orm::Result& fileResult) {
                                                    if (fileResult.size() != 1) {
                                                        trans->rollback();
                                                        StorageService::instance().deleteFile(
                                                            dstPath);
                                                        Logger::error(
                                                            "moveFile: UPDATE files affected " +
                                                                std::to_string(fileResult.size()) +
                                                                " rows, expected 1; fileId=" +
                                                                fileId,
                                                            userId, requestId);
                                                        exceptCb(drogon::orm::SqlError(
                                                            "moveFile: update failed",
                                                            "", nullptr));
                                                        return;
                                                    }
                                                    File updated = File::fromRow(fileResult[0]);
                                                    Logger::info(
                                                        "moveFile: UPDATE files OK fileId=" +
                                                            fileId + " srcBucket=" + f.bucketId +
                                                            " dstBucket=" + updated.bucketId +
                                                            " rows_affected=1",
                                                        userId, requestId);

                                                    const char* decSql =
                                                        "UPDATE buckets SET storage_used = "
                                                        "GREATEST(0, storage_used - $1), "
                                                        "updated_at = CURRENT_TIMESTAMP "
                                                        "WHERE id = $2 AND deleted_at IS NULL";
                                                    trans->execSqlAsync(
                                                        decSql,
                                                        [trans, &storage, f, srcPath, dstPath,
                                                         updated, successCb, exceptCb, userId, requestId](
                                                            const drogon::orm::Result&) {
                                                            const char* incSql =
                                                                "UPDATE buckets SET "
                                                                "storage_used = storage_used + $1, "
                                                                "updated_at = CURRENT_TIMESTAMP "
                                                                "WHERE id = $2 AND deleted_at IS NULL";
                                                            trans->execSqlAsync(
                                                                incSql,
                                                                [&storage, srcPath, updated,
                                                                 successCb, userId, requestId](
                                                                    const drogon::orm::Result&) {
                                                                    std::string delErr;
                                                                    if (!storage.deleteFile(
                                                                            srcPath, &delErr)) {
                                                                        Logger::error(
                                                                            "moveFile: failed to "
                                                                            "delete source file "
                                                                            "after move: " +
                                                                                srcPath +
                                                                                ", error: " +
                                                                                delErr,
                                                                            userId, requestId);
                                                                    }
                                                                    successCb(updated);
                                                                },
                                                                [trans, dstPath, exceptCb, userId, requestId](
                                                                    const drogon::orm::
                                                                        DrogonDbException& e) {
                                                                    trans->rollback();
                                                                    StorageService::instance()
                                                                        .deleteFile(dstPath);
                                                                    Logger::error(
                                                                        "moveFile: UPDATE dest "
                                                                        "bucket failed: " +
                                                                            std::string(
                                                                                e.base().what()),
                                                                        userId, requestId);
                                                                    exceptCb(e);
                                                                },
                                                                f.size,
                                                                updated.bucketId);
                                                        },
                                                        [trans, dstPath, exceptCb, userId, requestId](
                                                            const drogon::orm::
                                                                DrogonDbException& e) {
                                                            trans->rollback();
                                                            StorageService::instance().deleteFile(
                                                                dstPath);
                                                            Logger::error(
                                                                "moveFile: UPDATE source bucket "
                                                                "failed: " +
                                                                    std::string(e.base().what()),
                                                                userId, requestId);
                                                            exceptCb(e);
                                                        },
                                                        f.size,
                                                        f.bucketId);
                                                };

                                            Logger::info(
                                                "moveFile: cross-bucket UPDATE files fileId=" +
                                                    fileId + " srcBucket=" + f.bucketId +
                                                    " dstBucket=" + *newBucketId,
                                                userId, requestId);
                                            if (parentIdForDb.empty()) {
                                                const char* fileSql =
                                                    "UPDATE files SET bucket_id = $1, "
                                                    "parent_folder_id = NULL, path = $2, "
                                                    "updated_at = CURRENT_TIMESTAMP "
                                                    "WHERE id = $3 AND deleted_at IS NULL "
                                                    "RETURNING *";
                                                trans->execSqlAsync(
                                                    fileSql,
                                                    doUpdateBuckets,
                                                    onFileUpdateFailed,
                                                    *newBucketId,
                                                    newPath,
                                                    fileId);
                                            } else {
                                                const char* fileSql =
                                                    "UPDATE files SET bucket_id = $1, "
                                                    "parent_folder_id = $2, path = $3, "
                                                    "updated_at = CURRENT_TIMESTAMP "
                                                    "WHERE id = $4 AND deleted_at IS NULL "
                                                    "RETURNING *";
                                                trans->execSqlAsync(
                                                    fileSql,
                                                    doUpdateBuckets,
                                                    onFileUpdateFailed,
                                                    *newBucketId,
                                                    parentIdForDb,
                                                    newPath,
                                                    fileId);
                                            }
                                        });
                                },
                                exceptCb);
                        };

                        if (newParentFolderId.empty()) {
                            doCrossBucketMove(f.name);
                        } else {
                            const char* parentSql =
                                "SELECT path FROM files WHERE id = $1 AND user_id = $2 "
                                "AND bucket_id = $3 AND is_folder = true AND deleted_at IS NULL";
                            db.execSqlAsync(
                                parentSql,
                                [&db, &storage, &bucketSvc, f, fileId, userId,
                                 newParentFolderId, newBucketId, requestId, successCb, exceptCb,
                                 doCrossBucketMove](const drogon::orm::Result& pr) {
                                    if (pr.size() == 0) {
                                        Logger::error(
                                            "moveFile: new parent folder not found",
                                            userId, requestId);
                                        exceptCb(drogon::orm::SqlError(
                                            "New parent folder not found", "", nullptr));
                                        return;
                                    }
                                    std::string parentPath = pr[0]["path"].as<std::string>();
                                    doCrossBucketMove(parentPath + f.name);
                                },
                                exceptCb,
                                newParentFolderId,
                                userId,
                                *newBucketId);
                        }
                    },
                    exceptCb,
                    *newBucketId,
                    userId);
                return;
            }

            auto doUpdate = [&db, fileId, userId, requestId, successCb, exceptCb](
                               const std::string& newPath,
                               std::optional<std::string> parentId) {
                auto onResult = [successCb, exceptCb, userId, requestId](
                                    const drogon::orm::Result& r) {
                    if (r.size() == 0) {
                        Logger::error("moveFile: UPDATE affected no rows", userId, requestId);
                        exceptCb(drogon::orm::SqlError(
                            "moveFile: update failed", "", nullptr));
                        return;
                    }
                    successCb(File::fromRow(r[0]));
                };
                if (parentId && !parentId->empty()) {
                    const char* sql =
                        "UPDATE files SET parent_folder_id = $1, path = $2, "
                        "updated_at = CURRENT_TIMESTAMP WHERE id = $3 AND deleted_at IS NULL "
                        "RETURNING *";
                    db.execSqlAsync(sql, onResult, exceptCb, *parentId, newPath, fileId);
                } else {
                    const char* sql =
                        "UPDATE files SET parent_folder_id = NULL, path = $1, "
                        "updated_at = CURRENT_TIMESTAMP WHERE id = $2 AND deleted_at IS NULL "
                        "RETURNING *";
                    db.execSqlAsync(sql, onResult, exceptCb, newPath, fileId);
                }
            };

            std::string newPath;
            if (newParentFolderId.empty()) {
                newPath = f.isFolder ? f.name + "/" : f.name;
                doUpdate(newPath, std::nullopt);
                return;
            }

            const char* parentSql =
                "SELECT path FROM files WHERE id = $1 AND user_id = $2 AND bucket_id = $3 "
                "AND is_folder = true AND deleted_at IS NULL";
            db.execSqlAsync(
                parentSql,
                [f, doUpdate, newParentFolderId, fileId, userId, requestId, successCb,
                 exceptCb](const drogon::orm::Result& r) {
                    if (r.size() == 0) {
                        Logger::error("moveFile: new parent folder not found", userId, requestId);
                        exceptCb(drogon::orm::SqlError("New parent folder not found", "", nullptr));
                        return;
                    }
                    std::string parentPath = r[0]["path"].as<std::string>();
                    std::string newPath =
                        f.isFolder ? parentPath + f.name + "/" : parentPath + f.name;
                    doUpdate(newPath, newParentFolderId);
                },
                exceptCb,
                newParentFolderId,
                userId,
                f.bucketId);
        },
        exceptCb,
        fileId,
        userId);
}

void FileService::deleteFile(
    const std::string& fileId,
    const std::string& userId,
    std::function<void(const File&)> successCb,
    std::function<void(const drogon::orm::DrogonDbException&)> exceptCb,
    const std::string& requestId) {
    auto& db = DatabaseService::instance();

    auto doSoftDelete = [&db, successCb, exceptCb, requestId](
                           const File& f,
                           const std::string& fid,
                           const std::string& uid) {
        db.newTransactionAsync(
            [f, fid, uid, successCb, exceptCb, requestId](
                const std::shared_ptr<drogon::orm::Transaction>& trans) {
                auto runUpdate = [f, trans, uid, successCb, exceptCb, requestId,
                                 fid]() {
                    const char* updateFileSql =
                        "UPDATE files SET deleted_at = CURRENT_TIMESTAMP, "
                        "updated_at = CURRENT_TIMESTAMP WHERE id = $1 AND user_id = $2 "
                        "AND deleted_at IS NULL RETURNING *";
                    trans->execSqlAsync(
                        updateFileSql,
                        [f, trans, uid, successCb, exceptCb, requestId](
                            const drogon::orm::Result& r) {
                            if (r.size() == 0) {
                                Logger::error(
                                    "deleteFile: UPDATE files affected no rows",
                                    uid, requestId);
                                trans->rollback();
                                if (exceptCb) {
                                    exceptCb(drogon::orm::SqlError(
                                        "deleteFile: update failed", "", nullptr));
                                }
                                return;
                            }

                            if (f.isFolder || f.size == 0) {
                                if (successCb) successCb(f);
                                return;
                            }

                            const char* updateBucketSql =
                                "UPDATE buckets SET storage_used = GREATEST(0, "
                                "storage_used - $1), updated_at = CURRENT_TIMESTAMP "
                                "WHERE id = $2 AND deleted_at IS NULL";
                            trans->execSqlAsync(
                                updateBucketSql,
                                [f, successCb](const drogon::orm::Result&) {
                                    if (successCb) successCb(f);
                                },
                                [trans, uid, exceptCb, requestId](
                                    const drogon::orm::DrogonDbException& e) {
                                    trans->rollback();
                                    Logger::error(
                                        "deleteFile: UPDATE buckets failed: " +
                                            std::string(e.base().what()),
                                        uid, requestId);
                                    if (exceptCb) exceptCb(e);
                                },
                                f.size,
                                f.bucketId);
                        },
                        [trans, uid, exceptCb, requestId](
                            const drogon::orm::DrogonDbException& e) {
                            trans->rollback();
                            Logger::error("deleteFile: UPDATE files failed: " +
                                             std::string(e.base().what()),
                                         uid, requestId);
                            if (exceptCb) exceptCb(e);
                        },
                        fid,
                        uid);
                };

                if (f.isFolder) {
                    const char* countSql =
                        "SELECT COUNT(*) AS cnt FROM files WHERE parent_folder_id = $1 "
                        "AND deleted_at IS NULL";
                    trans->execSqlAsync(
                        countSql,
                        [f, trans, fid, uid, successCb, exceptCb, requestId,
                         runUpdate](const drogon::orm::Result& countResult) {
                            int64_t childCount =
                                countResult[0]["cnt"].as<int64_t>();
                            if (childCount > 0) {
                                Logger::error("deleteFile: folder is not empty",
                                              uid, requestId);
                                trans->rollback();
                                if (exceptCb) {
                                    exceptCb(drogon::orm::SqlError(
                                        "Folder is not empty", "", nullptr));
                                }
                                return;
                            }
                            runUpdate();
                        },
                        [trans, uid, exceptCb, requestId](
                            const drogon::orm::DrogonDbException& e) {
                            trans->rollback();
                            Logger::error(
                                "deleteFile: COUNT children failed: " +
                                    std::string(e.base().what()),
                                uid, requestId);
                            if (exceptCb) exceptCb(e);
                        },
                        fid);
                } else {
                    runUpdate();
                }
            });
    };

    const char* fetchSql =
        "SELECT * FROM files WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL";
    db.execSqlAsync(
        fetchSql,
        [fileId, userId, successCb, exceptCb, doSoftDelete, requestId](
            const drogon::orm::Result& r) {
            if (r.size() == 0) {
                Logger::error("deleteFile: file not found or access denied",
                              userId, requestId);
                if (exceptCb) {
                    exceptCb(drogon::orm::SqlError(
                        "File not found or access denied", "", nullptr));
                }
                return;
            }
            File f = File::fromRow(r[0]);
            doSoftDelete(f, fileId, userId);
        },
        exceptCb,
        fileId,
        userId);
}

}

