/**
 * @file FilesController.cc
 * @brief Implementation of upload and download with streaming.
 *
 * Write to disk FIRST, then DB. On rollback: delete file from disk.
 */

#include "controllers/FilesController.h"
#include "models/Bucket.h"
#include "models/File.h"
#include "services/BucketService.h"
#include "services/DatabaseService.h"
#include "services/DedupService.h"
#include "services/FileService.h"
#include "services/SecurityService.h"
#include "services/ShareService.h"
#include "services/StorageService.h"
#include "utils/Logger.h"
#include "utils/ResponseHelper.h"
#include "utils/UUIDGenerator.h"
#include <drogon/MultiPart.h>
#include <drogon/drogon.h>
#include <drogon/orm/Exception.h>
#include <cerrno>
#include <memory>
#include <json/json.h>
#include <optional>
#include <regex>

namespace s3 {

namespace {

constexpr size_t kStreamThresholdBytes = 1048576;  // 1MB

const std::regex kUuidRegex{
    R"(^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$)"};

const char* const kUuidFormatHint =
    "Expected: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (8-4-4-4-12 hex digits)";

std::string invalidUuidMessage(const char* field) {
    return std::string("Invalid ") + field + " format. " + kUuidFormatHint;
}

bool isValidUuid(const std::string& s) {
    return !s.empty() && std::regex_match(s, kUuidRegex);
}

std::string contentTypeToMime(drogon::ContentType ct) {
    switch (ct) {
        case drogon::CT_APPLICATION_JSON:
            return "application/json";
        case drogon::CT_APPLICATION_PDF:
            return "application/pdf";
        case drogon::CT_APPLICATION_ZIP:
            return "application/zip";
        case drogon::CT_APPLICATION_MSWORD:
            return "application/msword";
        case drogon::CT_APPLICATION_MSWORDX:
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
        case drogon::CT_TEXT_PLAIN:
            return "text/plain";
        case drogon::CT_TEXT_HTML:
            return "text/html";
        case drogon::CT_TEXT_CSV:
            return "text/csv";
        case drogon::CT_IMAGE_JPG:
            return "image/jpeg";
        case drogon::CT_IMAGE_PNG:
            return "image/png";
        case drogon::CT_IMAGE_GIF:
            return "image/gif";
        case drogon::CT_IMAGE_WEBP:
            return "image/webp";
        case drogon::CT_IMAGE_SVG_XML:
            return "image/svg+xml";
        default:
            return "application/octet-stream";
    }
}

}  // namespace

// POST /files/buckets/create — создание бакета (name обязателен)
void FilesController::createBucket(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) {
    auto [userId, requestId] = Logger::getContextFromRequest(req);

    if (userId.empty()) {
        ResponseHelper::sendError(req, "UNAUTHORIZED", "Missing X-User-Id", 401,
                                 std::move(callback));
        return;
    }

    auto json = req->getJsonObject();
    if (!json || !json->isMember("name")) {
        ResponseHelper::sendError(req, "BAD_REQUEST",
                                 "Missing required field: name", 400,
                                 std::move(callback));
        return;
    }

    std::string name = (*json)["name"].asString();
    if (name.empty()) {
        ResponseHelper::sendError(req, "BAD_REQUEST", "name must be non-empty",
                                 400, std::move(callback));
        return;
    }

    std::string description;
    if (json->isMember("description") && !(*json)["description"].isNull()) {
        description = (*json)["description"].asString();
    }

    bool isPublic = false;
    if (json->isMember("isPublic") && !(*json)["isPublic"].isNull()) {
        isPublic = (*json)["isPublic"].asBool();
    }

    BucketService::instance().createBucket(
        userId,
        name,
        description,
        isPublic,
        [req, callback](const Bucket& bucket) {
            Json::Value data = bucket.toJson();
            ResponseHelper::sendSuccess(req, std::move(data),
                                       std::move(callback), 201);
        },
        [req, userId, requestId, callback](
            const drogon::orm::DrogonDbException& e) {
            Logger::error("createBucket failed: " + std::string(e.base().what()),
                          userId, requestId);
            ResponseHelper::sendError(req, "INTERNAL_ERROR",
                                     "Failed to create bucket", 500,
                                     std::move(callback));
        });
}

// GET /files/buckets/list — список бакетов текущего пользователя
void FilesController::listBuckets(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) {
    auto [userId, requestId] = Logger::getContextFromRequest(req);

    if (userId.empty()) {
        ResponseHelper::sendError(req, "UNAUTHORIZED", "Missing X-User-Id", 401,
                                 std::move(callback));
        return;
    }

    BucketService::instance().listBuckets(
        userId,
        [req, callback](const std::vector<Bucket>& buckets) {
            Json::Value arr(Json::arrayValue);
            for (const auto& b : buckets) {
                arr.append(b.toJson());
            }
            Json::Value data;
            data["buckets"] = arr;
            ResponseHelper::sendSuccess(req, std::move(data),
                                       std::move(callback));
        },
        [req, userId, requestId, callback](
            const drogon::orm::DrogonDbException& e) {
            Logger::error("listBuckets failed: " + std::string(e.base().what()),
                          userId, requestId);
            ResponseHelper::sendError(req, "INTERNAL_ERROR",
                                     "Failed to list buckets", 500,
                                     std::move(callback));
        });
}

void FilesController::createFolder(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) {
    auto [userId, requestId] = Logger::getContextFromRequest(req);

    if (userId.empty()) {
        ResponseHelper::sendError(req, "UNAUTHORIZED", "Missing X-User-Id", 401,
                                 std::move(callback));
        return;
    }

    auto json = req->getJsonObject();
    if (!json || !json->isMember("bucketId") || !json->isMember("name")) {
        ResponseHelper::sendError(req, "BAD_REQUEST",
                                 "Missing required fields: bucketId, name", 400,
                                 std::move(callback));
        return;
    }

    std::string bucketId = (*json)["bucketId"].asString();
    std::string name = (*json)["name"].asString();

    if (!isValidUuid(bucketId)) {
        ResponseHelper::sendError(req, "BAD_REQUEST",
                                 invalidUuidMessage("bucketId"), 400,
                                 std::move(callback));
        return;
    }

    if (name.empty()) {
        ResponseHelper::sendError(req, "BAD_REQUEST", "name must be non-empty",
                                 400, std::move(callback));
        return;
    }

    std::string parentFolderId;
    if (json->isMember("parentFolderId") && !(*json)["parentFolderId"].isNull()) {
        parentFolderId = (*json)["parentFolderId"].asString();
        if (!parentFolderId.empty() && !isValidUuid(parentFolderId)) {
            ResponseHelper::sendError(req, "BAD_REQUEST",
                                     invalidUuidMessage("parentFolderId"), 400,
                                     std::move(callback));
            return;
        }
    }

    FileService::instance().createFolder(
        bucketId,
        userId,
        parentFolderId,
        name,
        [req, callback](const File& file) {
            Json::Value data = file.toJson();
            ResponseHelper::sendSuccess(req, std::move(data),
                                       std::move(callback), 201);
        },
        [req, userId, requestId, callback](
            const drogon::orm::DrogonDbException& e) {
            std::string msg = e.base().what();
            if (msg.find("Parent folder not found") != std::string::npos) {
                ResponseHelper::sendError(req, "NOT_FOUND", msg, 404,
                                         std::move(callback));
            } else {
                Logger::error("createFolder failed: " + msg, userId, requestId);
                ResponseHelper::sendError(req, "INTERNAL_ERROR",
                                         "Failed to create folder", 500,
                                         std::move(callback));
            }
        });
}

void FilesController::listFiles(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) {
    auto [userId, requestId] = Logger::getContextFromRequest(req);

    if (userId.empty()) {
        ResponseHelper::sendError(req, "UNAUTHORIZED", "Missing X-User-Id", 401,
                                 std::move(callback));
        return;
    }

    std::string bucketId = req->getParameter("bucket_id");
    if (bucketId.empty()) {
        ResponseHelper::sendError(req, "BAD_REQUEST", "Missing bucket_id", 400,
                                 std::move(callback));
        return;
    }

    if (!isValidUuid(bucketId)) {
        ResponseHelper::sendError(req, "BAD_REQUEST",
                                 invalidUuidMessage("bucket_id"), 400,
                                 std::move(callback));
        return;
    }

    std::string parentFolderId = req->getParameter("parent_folder_id");

    FileService::instance().listFiles(
        bucketId,
        userId,
        parentFolderId,
        [req, callback](const std::vector<File>& files) {
            Json::Value arr(Json::arrayValue);
            for (const auto& f : files) {
                arr.append(f.toJson());
            }
            Json::Value data;
            data["files"] = arr;
            auto resp = ResponseHelper::buildSuccess(req, std::move(data));
            resp->addHeader("Cache-Control", "no-store");
            callback(std::move(resp));
        },
        [req, userId, requestId, callback](
            const drogon::orm::DrogonDbException& e) {
            Logger::error("listFiles failed: " + std::string(e.base().what()),
                          userId, requestId);
            ResponseHelper::sendError(req, "INTERNAL_ERROR",
                                     "Failed to list files", 500,
                                     std::move(callback));
        });
}

void FilesController::upload(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) {
    std::string userId = req->getHeader("X-User-Id");
    auto [_, requestId] = Logger::getContextFromRequest(req);

    if (userId.empty()) {
        ResponseHelper::sendError(req, "UNAUTHORIZED", "Missing X-User-Id", 401,
                                 std::move(callback));
        return;
    }

    drogon::MultiPartParser parser;
    int parseResult = parser.parse(req);
    if (parseResult != 0) {
        Logger::warn("upload: multipart parse failed", userId, requestId);
        ResponseHelper::sendError(req, "BAD_REQUEST", "Invalid multipart body",
                                 400, std::move(callback));
        return;
    }

    auto files = parser.getFiles();
    if (files.empty()) {
        auto filesMap = parser.getFilesMap();
        auto it = filesMap.find("file");
        if (it == filesMap.end()) {
            ResponseHelper::sendError(req, "BAD_REQUEST",
                                     "Missing 'file' in multipart", 400,
                                     std::move(callback));
            return;
        }
        files = {it->second};
    } else {
        auto it = parser.getFilesMap().find("file");
        if (it != parser.getFilesMap().end()) {
            files = {it->second};
        }
    }

    const drogon::HttpFile fileToUpload = files[0];
    std::string fileName = fileToUpload.getFileName();
    size_t fileSize = fileToUpload.fileLength();

    if (fileName.empty()) {
        ResponseHelper::sendError(req, "BAD_REQUEST", "Empty file name", 400,
                                 std::move(callback));
        return;
    }

    if (!SecurityService::instance().validateUploadFile(fileName,
                                                       fileToUpload.getContentType())) {
        Logger::warn("upload: blocked file type: " + fileName, userId, requestId);
        ResponseHelper::sendError(req, "UNSUPPORTED_MEDIA_TYPE",
                                 "File type not allowed", 415,
                                 std::move(callback));
        return;
    }

    std::string bucketId = parser.getParameter<std::string>("bucket_id");
    std::string parentFolderId = parser.getParameter<std::string>("parent_folder_id");

    if (bucketId.empty()) {
        ResponseHelper::sendError(req, "BAD_REQUEST", "Missing bucket_id", 400,
                                 std::move(callback));
        return;
    }

    if (!isValidUuid(bucketId)) {
        ResponseHelper::sendError(req, "BAD_REQUEST",
                                 invalidUuidMessage("bucket_id"), 400,
                                 std::move(callback));
        return;
    }

    if (!parentFolderId.empty() && !isValidUuid(parentFolderId)) {
        ResponseHelper::sendError(req, "BAD_REQUEST",
                                 invalidUuidMessage("parent_folder_id"), 400,
                                 std::move(callback));
        return;
    }

    using HttpCb = std::function<void(const drogon::HttpResponsePtr&)>;
    auto cb = std::make_shared<HttpCb>(std::move(callback));

    BucketService::instance().checkQuota(
        bucketId,
        static_cast<int64_t>(fileSize),
        [req, userId, requestId, bucketId, parentFolderId, fileName, fileSize,
         fileToUpload, cb](QuotaCheckResult result) mutable {
            if (result != QuotaCheckResult::OK) {
                if (cb && *cb) {
                    if (result == QuotaCheckResult::NOT_FOUND) {
                        ResponseHelper::sendError(
                            req, "NOT_FOUND", "Bucket not found", 404,
                            std::move(*cb));
                    } else {
                        ResponseHelper::sendError(
                            req, "INSUFFICIENT_STORAGE",
                            "Bucket quota exceeded", 507,
                            std::move(*cb));
                    }
                }
                return;
            }

            auto& storage = StorageService::instance();
            std::string storageKey = storage.generateStorageKey();
            std::string fullPath =
                storage.getFullPath(userId, bucketId, storageKey);

            int saveResult = fileToUpload.saveAs(fullPath);
            if (saveResult != 0) {
                Logger::error("upload: failed to save file to " + fullPath,
                             userId, requestId);
                if (cb && *cb) {
                    if (saveResult == -1 && errno == ENOSPC) {
                        ResponseHelper::sendError(
                            req, "INSUFFICIENT_STORAGE", "Disk full", 507,
                            std::move(*cb));
                    } else {
                        ResponseHelper::sendError(
                            req, "INTERNAL_ERROR", "Failed to save file", 500,
                            std::move(*cb));
                    }
                }
                return;
            }

            std::string path;
            std::string fileId = UUIDGenerator::generateUUID();
            std::string mimeType = contentTypeToMime(fileToUpload.getContentType());

            auto& db = DatabaseService::instance();

            auto onDbError = [req, fullPath, cb, userId, requestId](
                                const drogon::orm::DrogonDbException& e) mutable {
                Logger::error("upload: DB error, rolling back: " +
                                 std::string(e.base().what()),
                             userId, requestId);
                StorageService::instance().deleteFile(fullPath);
                if (cb && *cb) {
                    ResponseHelper::sendError(
                        req, "INTERNAL_ERROR", "Database error", 500,
                        std::move(*cb));
                }
            };

            auto fetchParentAndInsert = [&db, fileId, bucketId, userId,
                                        parentFolderId, fileName, path,
                                        fileSize, mimeType, storageKey, fullPath,
                                        req, userIdCopy = userId, requestId,
                                        cb, onDbError](
                                           const std::string& parentPath) mutable {
                std::string filePath =
                    parentPath.empty() ? fileName : parentPath + fileName;

                db.newTransactionAsync(
                    [fileId, bucketId, userIdCopy, parentFolderId, fileName,
                     filePath, fileSize, mimeType, storageKey, fullPath, req,
                     requestId, cb, onDbError](
                        const std::shared_ptr<drogon::orm::Transaction>& trans) mutable {
                        const char* insertSql =
                            "INSERT INTO files (id, bucket_id, user_id, "
                            "parent_folder_id, name, path, size, mime_type, "
                            "storage_key, is_folder) "
                            "VALUES ($1, $2, $3, (NULLIF($4, ''))::uuid, $5, "
                            "$6, $7, $8, $9, false) RETURNING *";

                        trans->execSqlAsync(
                            insertSql,
                            [trans, bucketId, fileSize, fullPath, req, userIdCopy,
                             requestId, cb, onDbError](
                                const drogon::orm::Result& r) mutable {
                                if (r.size() == 0) {
                                    trans->rollback();
                                    onDbError(drogon::orm::SqlError(
                                        "Insert failed", "", nullptr));
                                    return;
                                }
                                File f = File::fromRow(r[0]);

                                const char* updateSql =
                                    "UPDATE buckets SET storage_used = "
                                    "storage_used + $1, updated_at = CURRENT_TIMESTAMP "
                                    "WHERE id = $2 AND deleted_at IS NULL";

                                trans->execSqlAsync(
                                    updateSql,
                                    [f, req, cb](
                                        const drogon::orm::Result&) mutable {
                                        if (cb && *cb) {
                                            Json::Value data = f.toJson();
                                            ResponseHelper::sendSuccess(
                                                req, std::move(data),
                                                std::move(*cb), 201);
                                        }
                                    },
                                    [trans, req, userIdCopy, requestId,
                                     cb, onDbError](
                                        const drogon::orm::DrogonDbException& e)
                                        mutable {
                                        trans->rollback();
                                        Logger::error(
                                            "upload: UPDATE buckets failed: " +
                                                std::string(e.base().what()),
                                            userIdCopy, requestId);
                                        onDbError(e);
                                    },
                                    fileSize,
                                    bucketId);
                            },
                            onDbError,
                            fileId,
                            bucketId,
                            userIdCopy,
                            parentFolderId,
                            fileName,
                            filePath,
                            static_cast<int64_t>(fileSize),
                            mimeType,
                            storageKey);
                    });
            };

            if (parentFolderId.empty()) {
                fetchParentAndInsert("");
                return;
            }

            const char* parentSql =
                "SELECT path FROM files WHERE id = $1 AND user_id = $2 "
                "AND bucket_id = $3 AND is_folder = true AND deleted_at IS NULL";
            db.execSqlAsync(
                parentSql,
                [fetchParentAndInsert, onDbError](
                    const drogon::orm::Result& r) mutable {
                    if (r.size() == 0) {
                        onDbError(drogon::orm::SqlError("Parent folder not found", "", nullptr));
                        return;
                    }
                    std::string parentPath = r[0]["path"].as<std::string>();
                    fetchParentAndInsert(parentPath);
                },
                onDbError,
                parentFolderId,
                userId,
                bucketId);
        },
        [req, cb, userId, requestId](const drogon::orm::DrogonDbException& e) {
            Logger::error("upload: checkQuota failed: " +
                              std::string(e.base().what()),
                          userId, requestId);
            if (cb && *cb) {
                ResponseHelper::sendError(req, "INTERNAL_ERROR",
                                         "Failed to check quota", 500,
                                         std::move(*cb));
            }
        });
}

void FilesController::download(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) {
    std::string userId = req->getHeader("X-User-Id");
    auto [_, requestId] = Logger::getContextFromRequest(req);

    if (userId.empty()) {
        ResponseHelper::sendError(req, "UNAUTHORIZED", "Missing X-User-Id", 401,
                                 std::move(callback));
        return;
    }

    std::string fileId = req->getParameter("file_id");
    if (fileId.empty()) {
        ResponseHelper::sendError(req, "BAD_REQUEST", "Missing file_id", 400,
                                 std::move(callback));
        return;
    }

    if (!isValidUuid(fileId)) {
        ResponseHelper::sendError(req, "BAD_REQUEST",
                                 invalidUuidMessage("file_id"), 400,
                                 std::move(callback));
        return;
    }

    using HttpCb = std::function<void(const drogon::HttpResponsePtr&)>;
    auto cb = std::make_shared<HttpCb>(std::move(callback));

    auto& db = DatabaseService::instance();
    const char* sql =
        "SELECT * FROM files WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL "
        "AND is_folder = false";
    db.execSqlAsync(
        sql,
        [req, userId, requestId, cb](const drogon::orm::Result& r) mutable {
            if (r.size() == 0) {
                if (cb && *cb) {
                    ResponseHelper::sendError(req, "NOT_FOUND", "File not found",
                                             404, std::move(*cb));
                }
                return;
            }
            File f = File::fromRow(r[0]);

            auto& storage = StorageService::instance();
            std::string fullPath = storage.getFullPath(f.userId, f.bucketId,
                                                       f.storageKey);

            std::string mimeType = f.mimeType.empty()
                                       ? "application/octet-stream"
                                       : f.mimeType;

            auto resp = drogon::HttpResponse::newFileResponse(
                fullPath, f.name,
                drogon::CT_CUSTOM, mimeType, req);

            if (resp->getStatusCode() == drogon::k416RequestedRangeNotSatisfiable) {
                if (cb && *cb) {
                    ResponseHelper::sendError(req, "RANGE_NOT_SATISFIABLE",
                                             "Invalid range", 416,
                                             std::move(*cb));
                }
                return;
            }

            std::string reqId = req->getHeader("x-request-id");
            if (!reqId.empty()) {
                resp->addHeader("X-Request-Id", reqId);
            }

            const char* updateSql =
                "UPDATE files SET download_count = download_count + 1 "
                "WHERE id = $1 AND deleted_at IS NULL";
            DatabaseService::instance().execSqlAsync(
                updateSql,
                [resp, cb](const drogon::orm::Result&) mutable {
                    if (cb && *cb) {
                        auto f = std::move(*cb);
                        f(resp);
                    }
                },
                [resp, cb](const drogon::orm::DrogonDbException&) mutable {
                    if (cb && *cb) {
                        auto f = std::move(*cb);
                        f(resp);
                    }
                },
                f.id);
        },
        [req, cb](const drogon::orm::DrogonDbException& e) mutable {
            if (cb && *cb) {
                ResponseHelper::sendError(req, "INTERNAL_ERROR",
                                         "Database error", 500,
                                         std::move(*cb));
            }
        },
        fileId,
        userId);
}

void FilesController::downloadShared(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    std::string token) {
    using HttpCb = std::function<void(const drogon::HttpResponsePtr&)>;
    auto cb = std::make_shared<HttpCb>(std::move(callback));

    ShareService::instance().getSharedLinkForDownload(
        token,
        [req, cb](const SharedLinkFileInfo& info) mutable {
            auto& storage = StorageService::instance();
            std::string fullPath =
                storage.getFullPath(info.userId, info.bucketId, info.storageKey);

            std::string mimeType = info.mimeType.empty()
                                      ? "application/octet-stream"
                                      : info.mimeType;

            auto resp = drogon::HttpResponse::newFileResponse(
                fullPath, info.name, drogon::CT_CUSTOM, mimeType, req);

            if (resp->getStatusCode() ==
                drogon::k416RequestedRangeNotSatisfiable) {
                if (cb && *cb) {
                    ResponseHelper::sendError(req, "RANGE_NOT_SATISFIABLE",
                                             "Invalid range", 416,
                                             std::move(*cb));
                }
                return;
            }

            std::string reqId = req->getHeader("x-request-id");
            if (!reqId.empty()) {
                resp->addHeader("X-Request-Id", reqId);
            }

            ShareService::instance().incrementSharedDownloadCounts(
                info.id,
                info.fileId,
                [resp, cb]() mutable {
                    if (cb && *cb) {
                        auto f = std::move(*cb);
                        f(resp);
                    }
                },
                [resp, cb](const std::string&, const std::string&, int) mutable {
                    if (cb && *cb) {
                        auto f = std::move(*cb);
                        f(resp);
                    }
                });
        },
        [req, cb](const std::string& code,
                  const std::string& message,
                  int statusCode) mutable {
            if (cb && *cb) {
                ResponseHelper::sendError(req, code, message, statusCode,
                                         std::move(*cb));
            }
        });
}

void FilesController::moveFile(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) {
    auto [userId, requestId] = Logger::getContextFromRequest(req);

    if (userId.empty()) {
        ResponseHelper::sendError(req, "UNAUTHORIZED", "Missing X-User-Id", 401,
                                 std::move(callback));
        return;
    }

    auto json = req->getJsonObject();
    if (!json || !json->isMember("fileId")) {
        ResponseHelper::sendError(req, "BAD_REQUEST",
                                 "Missing required field: fileId", 400,
                                 std::move(callback));
        return;
    }

    std::string fileId = (*json)["fileId"].asString();
    if (!isValidUuid(fileId)) {
        ResponseHelper::sendError(req, "BAD_REQUEST",
                                 invalidUuidMessage("fileId"), 400,
                                 std::move(callback));
        return;
    }

    std::string newParentFolderId;
    if (json->isMember("newParentFolderId") &&
        !(*json)["newParentFolderId"].isNull()) {
        newParentFolderId = (*json)["newParentFolderId"].asString();
        if (!newParentFolderId.empty() && !isValidUuid(newParentFolderId)) {
            ResponseHelper::sendError(req, "BAD_REQUEST",
                                     invalidUuidMessage("newParentFolderId"),
                                     400, std::move(callback));
            return;
        }
    }

    std::optional<std::string> newBucketId;
    if (json->isMember("newBucketId") && !(*json)["newBucketId"].isNull()) {
        std::string val = (*json)["newBucketId"].asString();
        if (!val.empty()) {
            if (!isValidUuid(val)) {
                ResponseHelper::sendError(req, "BAD_REQUEST",
                                         invalidUuidMessage("newBucketId"),
                                         400, std::move(callback));
                return;
            }
            newBucketId = val;
        }
    }

    FileService::instance().moveFile(
        fileId,
        userId,
        newParentFolderId,
        [req, callback](const File& file) {
            Json::Value data = file.toJson();
            ResponseHelper::sendSuccess(req, std::move(data),
                                       std::move(callback));
        },
        [req, userId, requestId, callback](
            const drogon::orm::DrogonDbException& e) {
            std::string msg = e.base().what();
            int statusCode = 500;
            std::string code = "INTERNAL_ERROR";

            if (msg.find("Folder move between buckets not supported") !=
                std::string::npos) {
                code = "BAD_REQUEST";
                statusCode = 400;
            } else if (msg.find("Destination bucket not found") !=
                       std::string::npos ||
                       msg.find("New parent folder not found") !=
                           std::string::npos ||
                       msg.find("File not found or access denied") !=
                           std::string::npos ||
                       msg.find("not found") != std::string::npos ||
                       msg.find("access denied") != std::string::npos) {
                code = "NOT_FOUND";
                statusCode = 404;
            } else if (msg.find("Quota exceeded") != std::string::npos) {
                code = "FORBIDDEN";
                statusCode = 403;
            } else if (msg.find("Disk full") != std::string::npos ||
                       msg.find("Insufficient storage") != std::string::npos) {
                code = "INSUFFICIENT_STORAGE";
                statusCode = 507;
            } else {
                Logger::error("moveFile failed: " + msg, userId, requestId);
            }
            ResponseHelper::sendError(req, code, msg, statusCode,
                                     std::move(callback));
        },
        newBucketId,
        requestId);
}

void FilesController::createShareLink(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) {
    auto [userId, requestId] = Logger::getContextFromRequest(req);

    if (userId.empty()) {
        ResponseHelper::sendError(req, "UNAUTHORIZED", "Missing X-User-Id", 401,
                                 std::move(callback));
        return;
    }

    auto json = req->getJsonObject();
    if (!json || !json->isMember("fileId")) {
        ResponseHelper::sendError(req, "BAD_REQUEST",
                                  "Missing required field: fileId", 400,
                                  std::move(callback));
        return;
    }

    std::string fileId = (*json)["fileId"].asString();
    if (!isValidUuid(fileId)) {
        ResponseHelper::sendError(req, "BAD_REQUEST",
                                 invalidUuidMessage("fileId"), 400,
                                 std::move(callback));
        return;
    }

    std::optional<std::string> expiresAt;
    if (json->isMember("expiresAt") && !(*json)["expiresAt"].isNull()) {
        expiresAt = (*json)["expiresAt"].asString();
    }

    std::optional<int> maxDownloads;
    if (json->isMember("maxDownloads") && !(*json)["maxDownloads"].isNull()) {
        int v = (*json)["maxDownloads"].asInt();
        if (v < 0) {
            ResponseHelper::sendError(req, "BAD_REQUEST",
                                      "maxDownloads must be non-negative", 400,
                                      std::move(callback));
            return;
        }
        maxDownloads = v;
    }

    auto& shareSvc = ShareService::instance();
    shareSvc.createSharedLink(
        fileId,
        userId,
        expiresAt,
        maxDownloads,
        [req, callback](const ShareLinkResult& result) {
            Json::Value data;
            data["id"] = result.id;
            data["token"] = result.token;
            data["expiresAt"] =
                result.expiresAt.empty() ? Json::Value() : result.expiresAt;
            data["maxDownloads"] = result.maxDownloads;
            data["createdAt"] = result.createdAt;
            ResponseHelper::sendSuccess(req, std::move(data), std::move(callback),
                                       201);
        },
        [req, callback, userId, requestId](
            const drogon::orm::DrogonDbException& e) {
            std::string msg = e.base().what();
            if (msg.find("not found") != std::string::npos ||
                msg.find("do not have access") != std::string::npos) {
                ResponseHelper::sendError(req, "FORBIDDEN", msg, 403,
                                          std::move(callback));
            } else {
                Logger::error("createShareLink failed: " + msg, userId, requestId);
                ResponseHelper::sendError(req, "INTERNAL_ERROR",
                                          "Failed to create shared link", 500,
                                          std::move(callback));
            }
        });
}

void FilesController::performDeleteFile(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& fileId,
    const std::string& userId,
    const std::string& requestId) {
    using HttpCb = std::function<void(const drogon::HttpResponsePtr&)>;
    auto cb = std::make_shared<HttpCb>(std::move(callback));

    FileService::instance().deleteFile(
        fileId,
        userId,
        [req, cb](const File& file) {
            if (cb && *cb) {
                Json::Value data = file.toJson();
                ResponseHelper::sendSuccess(req, std::move(data), std::move(*cb));
            }
        },
        [req, userId, requestId, cb](
            const drogon::orm::DrogonDbException& e) {
            if (cb && *cb) {
                std::string msg = e.base().what();
                int statusCode = 500;
                std::string code = "INTERNAL_ERROR";
                if (msg.find("not found") != std::string::npos ||
                    msg.find("access denied") != std::string::npos) {
                    code = "NOT_FOUND";
                    statusCode = 404;
                } else if (msg.find("Folder is not empty") != std::string::npos) {
                    code = "BAD_REQUEST";
                    statusCode = 400;
                } else {
                    Logger::error("deleteFile failed: " + msg, userId, requestId);
                }
                ResponseHelper::sendError(req, code, msg, statusCode, std::move(*cb));
            }
        },
        requestId);
}

void FilesController::deleteFile(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) {
    auto [userId, requestId] = Logger::getContextFromRequest(req);

    if (userId.empty()) {
        ResponseHelper::sendError(req, "UNAUTHORIZED", "Missing X-User-Id", 401,
                                 std::move(callback));
        return;
    }

    auto json = req->getJsonObject();
    if (!json || !json->isMember("fileId")) {
        ResponseHelper::sendError(req, "BAD_REQUEST",
                                 "Missing required field: fileId", 400,
                                 std::move(callback));
        return;
    }

    std::string fileId = (*json)["fileId"].asString();
    if (!isValidUuid(fileId)) {
        ResponseHelper::sendError(req, "BAD_REQUEST",
                                 invalidUuidMessage("fileId"), 400,
                                 std::move(callback));
        return;
    }

    performDeleteFile(req, std::move(callback), fileId, userId, requestId);
}

void FilesController::deleteFileRest(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    std::string fileId) {
    auto [userId, requestId] = Logger::getContextFromRequest(req);

    if (userId.empty()) {
        ResponseHelper::sendError(req, "UNAUTHORIZED", "Missing X-User-Id", 401,
                                 std::move(callback));
        return;
    }

    if (!isValidUuid(fileId)) {
        ResponseHelper::sendError(req, "BAD_REQUEST",
                                 invalidUuidMessage("fileId"), 400,
                                 std::move(callback));
        return;
    }

    performDeleteFile(req, std::move(callback), fileId, userId, requestId);
}

void FilesController::performDeleteBucket(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& bucketId,
    const std::string& userId,
    const std::string& requestId) {
    using HttpCb = std::function<void(const drogon::HttpResponsePtr&)>;
    auto cb = std::make_shared<HttpCb>(std::move(callback));

    BucketService::instance().deleteBucket(
        bucketId,
        userId,
        [req, cb](const Bucket& bucket) {
            if (cb && *cb) {
                Json::Value data = bucket.toJson();
                ResponseHelper::sendSuccess(req, std::move(data), std::move(*cb));
            }
        },
        [req, userId, requestId, cb, bucketId](
            const drogon::orm::DrogonDbException& e) {
            if (cb && *cb) {
                std::string msg = e.base().what();
                int statusCode = 500;
                std::string code = "INTERNAL_ERROR";
                if (msg.find("not found") != std::string::npos ||
                    msg.find("access denied") != std::string::npos) {
                    code = "NOT_FOUND";
                    statusCode = 404;
                } else if (msg.find("Bucket is not empty") != std::string::npos) {
                    code = "BAD_REQUEST";
                    statusCode = 400;
                } else {
                    Logger::error("deleteBucket failed: " + msg, userId, requestId);
                }
                ResponseHelper::sendError(req, code, msg, statusCode, std::move(*cb));
            }
        },
        requestId);
}

void FilesController::deleteBucket(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) {
    auto [userId, requestId] = Logger::getContextFromRequest(req);

    if (userId.empty()) {
        ResponseHelper::sendError(req, "UNAUTHORIZED", "Missing X-User-Id", 401,
                                 std::move(callback));
        return;
    }

    auto json = req->getJsonObject();
    if (!json || !json->isMember("bucketId")) {
        ResponseHelper::sendError(req, "BAD_REQUEST",
                                 "Missing required field: bucketId", 400,
                                 std::move(callback));
        return;
    }

    std::string bucketId = (*json)["bucketId"].asString();
    if (!isValidUuid(bucketId)) {
        ResponseHelper::sendError(req, "BAD_REQUEST",
                                 invalidUuidMessage("bucketId"), 400,
                                 std::move(callback));
        return;
    }

    performDeleteBucket(req, std::move(callback), bucketId, userId, requestId);
}

void FilesController::deleteBucketRest(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    std::string bucketId) {
    auto [userId, requestId] = Logger::getContextFromRequest(req);

    if (userId.empty()) {
        ResponseHelper::sendError(req, "UNAUTHORIZED", "Missing X-User-Id", 401,
                                 std::move(callback));
        return;
    }

    if (!isValidUuid(bucketId)) {
        ResponseHelper::sendError(req, "BAD_REQUEST",
                                 invalidUuidMessage("bucketId"), 400,
                                 std::move(callback));
        return;
    }

    performDeleteBucket(req, std::move(callback), bucketId, userId, requestId);
}

void FilesController::deduplicateBucketRest(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    std::string bucketId) {
    auto [userId, requestId] = Logger::getContextFromRequest(req);

    if (userId.empty()) {
        ResponseHelper::sendError(req, "UNAUTHORIZED", "Missing X-User-Id", 401,
                                 std::move(callback));
        return;
    }

    if (!isValidUuid(bucketId)) {
        ResponseHelper::sendError(req, "BAD_REQUEST",
                                 invalidUuidMessage("bucketId"), 400,
                                 std::move(callback));
        return;
    }

    DedupService::instance().deduplicateBucket(
        bucketId,
        userId,
        [req, callback](int removedCount, int64_t removedSize) {
            Json::Value data;
            data["removedCount"] = removedCount;
            data["removedSize"] = static_cast<Json::Int64>(removedSize);
            ResponseHelper::sendSuccess(req, std::move(data), std::move(callback));
        },
        [req, userId, requestId, callback](const std::exception& e) {
            std::string msg = e.what();
            int statusCode = 500;
            std::string code = "INTERNAL_ERROR";
            if (msg.find("not found") != std::string::npos ||
                msg.find("access denied") != std::string::npos) {
                code = "NOT_FOUND";
                statusCode = 404;
            } else if (msg.find("invalid") != std::string::npos) {
                code = "BAD_REQUEST";
                statusCode = 400;
            } else {
                Logger::error("deduplicateBucket failed: " + msg, userId,
                              requestId);
            }
            ResponseHelper::sendError(req, code, msg, statusCode,
                                     std::move(callback));
        },
        requestId);
}

} 
