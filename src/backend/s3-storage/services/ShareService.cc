/*
Implementation of ShareService — create shared link with token.
 */

#include "services/ShareService.h"
#include "services/DatabaseService.h"
#include "utils/Logger.h"
#include "utils/UUIDGenerator.h"
#include <drogon/orm/Exception.h>
#include <drogon/orm/Field.h>

namespace s3 {

namespace {

constexpr int kMaxTokenRetries = 3;

}  // namespace

ShareService& ShareService::instance() {
    static ShareService instance;
    return instance;
}

void ShareService::createSharedLink(
    const std::string& fileId,
    const std::string& userId,
    std::optional<std::string> expiresAt,
    std::optional<int> maxDownloads,
    std::function<void(const ShareLinkResult&)> successCb,
    std::function<void(const drogon::orm::DrogonDbException&)> exceptCb) {
    auto& db = DatabaseService::instance();

    // 1. Verify file exists, user owns it, not a folder
    const char* checkSql =
        "SELECT id FROM files WHERE id = $1 AND user_id = $2 AND "
        "deleted_at IS NULL AND is_folder = false";

    db.execSqlAsync(
        checkSql,
        [&db, fileId, userId, expiresAt, maxDownloads, successCb,
         exceptCb](const drogon::orm::Result& r) {
            if (r.size() == 0) {
                Logger::error("createSharedLink: file not found or not owned by user",
                              userId, "");
                exceptCb(drogon::orm::SqlError(
                    "File not found or you do not have access", "", nullptr));
                return;
            }

            // 2. Generate token and INSERT (retry on token collision)
            auto tryInsertPtr = std::make_shared<std::function<void(int)>>();
            *tryInsertPtr = [&db, tryInsertPtr, fileId, userId, expiresAt,
                            maxDownloads, successCb,
                            exceptCb](int attempt) {
                std::string linkId = UUIDGenerator::generateUUID();
                std::string token = UUIDGenerator::generateToken(32);

                const char* insertSql =
                    "INSERT INTO shared_links (id, file_id, user_id, token, "
                    "expires_at, max_downloads) VALUES ($1, $2, $3, $4, $5, $6) "
                    "RETURNING id, token, expires_at, max_downloads, created_at";

                auto onSuccess = [successCb, exceptCb](
                                    const drogon::orm::Result& res) {
                    if (res.size() == 0) {
                        Logger::error("createSharedLink: INSERT returned no rows",
                                      "", "");
                        exceptCb(drogon::orm::SqlError(
                            "createSharedLink: INSERT returned no rows", "",
                            nullptr));
                        return;
                    }
                    ShareLinkResult result;
                    result.id = res[0]["id"].as<std::string>();
                    result.token = res[0]["token"].as<std::string>();
                    result.expiresAt =
                        res[0]["expires_at"].isNull()
                            ? ""
                            : res[0]["expires_at"].as<std::string>();
                    result.maxDownloads =
                        res[0]["max_downloads"].isNull()
                            ? 0
                            : res[0]["max_downloads"].as<int>();
                    result.createdAt =
                        res[0]["created_at"].isNull()
                            ? ""
                            : res[0]["created_at"].as<std::string>();
                    successCb(result);
                };

                auto onError = [tryInsertPtr, attempt,
                                exceptCb](const drogon::orm::DrogonDbException& e) {
                    std::string msg = e.base().what();
                    bool isUniqueViolation =
                        (msg.find("23505") != std::string::npos) ||
                        (msg.find("unique") != std::string::npos &&
                         msg.find("violation") != std::string::npos);

                    if (isUniqueViolation && attempt < kMaxTokenRetries) {
                        (*tryInsertPtr)(attempt + 1);
                    } else {
                        exceptCb(e);
                    }
                };

                if (expiresAt && !expiresAt->empty()) {
                    if (maxDownloads && *maxDownloads > 0) {
                        db.execSqlAsync(insertSql, onSuccess, onError, linkId,
                                       fileId, userId, token, *expiresAt,
                                       *maxDownloads);
                    } else {
                        db.execSqlAsync(insertSql, onSuccess, onError, linkId,
                                       fileId, userId, token, *expiresAt,
                                       nullptr);
                    }
                } else {
                    if (maxDownloads && *maxDownloads > 0) {
                        db.execSqlAsync(insertSql, onSuccess, onError, linkId,
                                       fileId, userId, token, nullptr,
                                       *maxDownloads);
                    } else {
                        db.execSqlAsync(insertSql, onSuccess, onError, linkId,
                                       fileId, userId, token, nullptr,
                                       nullptr);
                    }
                }
            };

            (*tryInsertPtr)(0);
        },
        exceptCb,
        fileId,
        userId);
}

void ShareService::getSharedLinkForDownload(
    const std::string& token,
    std::function<void(const SharedLinkFileInfo&)> successCb,
    std::function<void(const std::string& code,
                       const std::string& message,
                       int statusCode)> errorCb) {
    auto& db = DatabaseService::instance();

    const char* sql =
        "SELECT sl.id, sl.file_id, sl.is_active, sl.expires_at, sl.max_downloads, "
        "sl.download_count, f.user_id, f.bucket_id, f.storage_key, f.name, f.mime_type, "
        "(sl.expires_at IS NOT NULL AND sl.expires_at < NOW()) as is_expired, "
        "(sl.max_downloads IS NOT NULL AND sl.max_downloads > 0 AND sl.download_count >= sl.max_downloads) as limit_reached "
        "FROM shared_links sl "
        "JOIN files f ON f.id = sl.file_id AND f.deleted_at IS NULL "
        "WHERE sl.token = $1";

    db.execSqlAsync(
        sql,
        [successCb, errorCb](const drogon::orm::Result& r) {
            if (r.size() == 0) {
                Logger::error("getSharedLinkForDownload: link not found", "", "");
                errorCb("NOT_FOUND", "Link not found", 404);
                return;
            }
            const auto& row = r[0];
            if (!row["is_active"].as<bool>()) {
                Logger::error("getSharedLinkForDownload: link revoked", "", "");
                errorCb("FORBIDDEN", "Link has been revoked", 403);
                return;
            }
            if (row["is_expired"].as<bool>()) {
                Logger::error("getSharedLinkForDownload: link expired", "", "");
                errorCb("NOT_FOUND", "Link has expired", 404);
                return;
            }
            if (row["limit_reached"].as<bool>()) {
                Logger::error("getSharedLinkForDownload: download limit reached", "", "");
                errorCb("NOT_FOUND", "Download limit reached", 404);
                return;
            }
            SharedLinkFileInfo info;
            info.id = row["id"].as<std::string>();
            info.fileId = row["file_id"].as<std::string>();
            info.userId = row["user_id"].as<std::string>();
            info.bucketId = row["bucket_id"].as<std::string>();
            info.storageKey = row["storage_key"].as<std::string>();
            info.name = row["name"].as<std::string>();
            info.mimeType = row["mime_type"].isNull()
                               ? "application/octet-stream"
                               : row["mime_type"].as<std::string>();
            successCb(info);
        },
        [errorCb](const drogon::orm::DrogonDbException& e) {
            errorCb("INTERNAL_ERROR", "Database error", 500);
        },
        token);
}

void ShareService::incrementSharedDownloadCounts(
    const std::string& sharedLinkId,
    const std::string& fileId,
    std::function<void()> doneCb,
    std::function<void(const std::string& code,
                       const std::string& message,
                       int statusCode)> errorCb) {
    auto& db = DatabaseService::instance();

    const char* updateLinkSql =
        "UPDATE shared_links SET download_count = download_count + 1 WHERE id = $1";
    const char* updateFileSql =
        "UPDATE files SET download_count = download_count + 1 "
        "WHERE id = $1 AND deleted_at IS NULL";

    db.execSqlAsync(
        updateLinkSql,
        [fileId, doneCb, errorCb, updateFileSql](const drogon::orm::Result&) {
            DatabaseService::instance().execSqlAsync(
                updateFileSql,
                [doneCb](const drogon::orm::Result&) { doneCb(); },
                [errorCb](const drogon::orm::DrogonDbException& e) {
                    Logger::error("incrementSharedDownloadCounts: database error", "", "");
                    errorCb("INTERNAL_ERROR", "Database error", 500);
                },
                fileId);
        },
        [errorCb](const drogon::orm::DrogonDbException& e) {
            Logger::error("incrementSharedDownloadCounts: database error", "", "");
            errorCb("INTERNAL_ERROR", "Database error", 500);
        },
        sharedLinkId);
}

}  // namespace s3
