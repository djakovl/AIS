
#pragma once

#include <drogon/drogon.h>

namespace s3 {

/*
  controller — 14 эндпоинтов.
 Бакеты: POST /files/buckets/create, GET /files/buckets/list,
          POST /files/buckets/delete (deprecated), DELETE /files/buckets/{bucket_id},
         POST /files/buckets/{bucket_id}/deduplicate
 Папки: POST /files/folders/create
 Файлы: GET /files/list, POST /files/upload, GET /files/download, GET /files/shared/{token},
         POST /files/move, POST /files/delete (deprecated), DELETE /files/{file_id}
 Ссылки: POST /files/share/create
 */
class FilesController : public drogon::HttpController<FilesController, false> {
public:
    void createBucket(const drogon::HttpRequestPtr& req,
                     std::function<void(const drogon::HttpResponsePtr&)>&& callback);
    void listBuckets(const drogon::HttpRequestPtr& req,
                     std::function<void(const drogon::HttpResponsePtr&)>&& callback);
    void createFolder(const drogon::HttpRequestPtr& req,
                     std::function<void(const drogon::HttpResponsePtr&)>&& callback);
    void listFiles(const drogon::HttpRequestPtr& req,
                   std::function<void(const drogon::HttpResponsePtr&)>&& callback);
    void upload(const drogon::HttpRequestPtr& req,
                std::function<void(const drogon::HttpResponsePtr&)>&& callback);
    void download(const drogon::HttpRequestPtr& req,
                  std::function<void(const drogon::HttpResponsePtr&)>&& callback);
    void moveFile(const drogon::HttpRequestPtr& req,
                  std::function<void(const drogon::HttpResponsePtr&)>&& callback);

    /*
     POST /files/share/create — create shared link for a file.
      Body: {"fileId": "uuid", "expiresAt": "ISO8601?", "maxDownloads": int?}
     */
    void createShareLink(
        const drogon::HttpRequestPtr& req,
        std::function<void(const drogon::HttpResponsePtr&)>&& callback);

    /*
     GET /files/shared/{token} — public download via shared link token.
     No auth; CORS and RateLimit only.
     */
    void downloadShared(const drogon::HttpRequestPtr& req,
                       std::function<void(const drogon::HttpResponsePtr&)>&& callback,
                       std::string token);

    /**
    POST /files/delete — soft delete file or folder.
    Body: {"fileId": "uuid"}
     */
    void deleteFile(const drogon::HttpRequestPtr& req,
                    std::function<void(const drogon::HttpResponsePtr&)>&& callback);

    /*
     DELETE /files/{file_id} — REST-style soft delete file or folder.
     file_id from path parameter.
     */
    void deleteFileRest(const drogon::HttpRequestPtr& req,
                        std::function<void(const drogon::HttpResponsePtr&)>&& callback,
                        std::string fileId);

    /*
     POST /files/buckets/delete — soft delete bucket.
     Body: {"bucketId": "uuid"}
     */
    void deleteBucket(const drogon::HttpRequestPtr& req,
                      std::function<void(const drogon::HttpResponsePtr&)>&& callback);

    /*
      DELETE /files/buckets/{bucket_id} — REST-style soft delete bucket.
      bucketId from path parameter.
     */
    void deleteBucketRest(const drogon::HttpRequestPtr& req,
                         std::function<void(const drogon::HttpResponsePtr&)>&& callback,
                         std::string bucketId);

    /*
     POST /files/buckets/{bucket_id}/deduplicate — deduplicate bucket.
     bucketId from path parameter.
     */
    void deduplicateBucketRest(const drogon::HttpRequestPtr& req,
                              std::function<void(const drogon::HttpResponsePtr&)>&& callback,
                              std::string bucketId);

private:
    void performDeleteBucket(const drogon::HttpRequestPtr& req,
                             std::function<void(const drogon::HttpResponsePtr&)>&& callback,
                             const std::string& bucketId,
                             const std::string& userId,
                             const std::string& requestId);
    void performDeleteFile(const drogon::HttpRequestPtr& req,
                           std::function<void(const drogon::HttpResponsePtr&)>&& callback,
                           const std::string& fileId,
                           const std::string& userId,
                           const std::string& requestId);

public:
    METHOD_LIST_BEGIN
    ADD_METHOD_TO(FilesController::createBucket,
                  "/files/buckets/create",
                  drogon::Post,
                  "s3::GatewayAuthFilter",
                  "s3::CORSFilter",
                  "s3::RateLimitFilter");
    ADD_METHOD_TO(FilesController::listBuckets,
                  "/files/buckets/list",
                  drogon::Get,
                  "s3::GatewayAuthFilter",
                  "s3::CORSFilter",
                  "s3::RateLimitFilter");
    ADD_METHOD_TO(FilesController::createFolder,
                  "/files/folders/create",
                  drogon::Post,
                  "s3::GatewayAuthFilter",
                  "s3::CORSFilter",
                  "s3::RateLimitFilter");
    ADD_METHOD_TO(FilesController::listFiles,
                  "/files/list",
                  drogon::Get,
                  "s3::GatewayAuthFilter",
                  "s3::CORSFilter",
                  "s3::RateLimitFilter");
    ADD_METHOD_TO(FilesController::upload,
                  "/files/upload",
                  drogon::Post,
                  "s3::GatewayAuthFilter",
                  "s3::CORSFilter",
                  "s3::RateLimitFilter");
    ADD_METHOD_TO(FilesController::download,
                  "/files/download",
                  drogon::Get,
                  "s3::GatewayAuthFilter",
                  "s3::CORSFilter",
                  "s3::RateLimitFilter");
    ADD_METHOD_TO(FilesController::moveFile,
                  "/files/move",
                  drogon::Post,
                  "s3::GatewayAuthFilter",
                  "s3::CORSFilter",
                  "s3::RateLimitFilter");
    ADD_METHOD_TO(FilesController::createShareLink,
                  "/files/share/create",
                  drogon::Post,
                  "s3::GatewayAuthFilter",
                  "s3::CORSFilter",
                  "s3::RateLimitFilter");
    ADD_METHOD_TO(FilesController::downloadShared,
                  "/files/shared/{1}",
                  drogon::Get,
                  "s3::CORSFilter",
                  "s3::RateLimitFilter");
    ADD_METHOD_TO(FilesController::deleteFile,
                  "/files/delete",
                  drogon::Post,
                  "s3::GatewayAuthFilter",
                  "s3::CORSFilter",
                  "s3::RateLimitFilter");
    ADD_METHOD_TO(FilesController::deduplicateBucketRest,
                  "/files/buckets/{1}/deduplicate",
                  drogon::Post,
                  "s3::GatewayAuthFilter",
                  "s3::CORSFilter",
                  "s3::RateLimitFilter");
    ADD_METHOD_TO(FilesController::deleteBucketRest,
                  "/files/buckets/{1}",
                  drogon::Delete,
                  "s3::GatewayAuthFilter",
                  "s3::CORSFilter",
                  "s3::RateLimitFilter");
    ADD_METHOD_TO(FilesController::deleteFileRest,
                  "/files/{1}",
                  drogon::Delete,
                  "s3::GatewayAuthFilter",
                  "s3::CORSFilter",
                  "s3::RateLimitFilter");
    ADD_METHOD_TO(FilesController::deleteBucket,
                  "/files/buckets/delete",
                  drogon::Post,
                  "s3::GatewayAuthFilter",
                  "s3::CORSFilter",
                  "s3::RateLimitFilter");
    METHOD_LIST_END
};

}  
