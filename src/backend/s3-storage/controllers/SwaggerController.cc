//Implementation of Swagger/OpenAPI documentation endpoints.
 

#include "controllers/SwaggerController.h"
#include "utils/Logger.h"
#include <cstdlib>
#include <drogon/drogon.h>
#include <json/json.h>

namespace s3 {

bool SwaggerController::isSwaggerEnabled() {
    const char* prod = std::getenv("PRODUCTION");
    if (prod) {
        std::string s(prod);
        if (s == "true" || s == "1") {
            return false;
        }
    }
    try {
        const auto& config = drogon::app().getCustomConfig();
        if (!config.empty() && config.isMember("swagger_enabled") &&
            !config["swagger_enabled"].asBool()) {
            return false;
        }
    } catch (...) {
        Logger::warn("SwaggerController: failed to read swagger_enabled config, "
                     "defaulting to enabled",
                     "", "");
    }
    return true;
}

namespace {

void addErrorResponses(Json::Value& op) {
    Json::Value ref;
    ref["$ref"] = "#/components/schemas/ErrorResponse";
    op["responses"]["500"]["description"] = "Internal Server Error";
    op["responses"]["500"]["content"]["application/json"]["schema"] = ref;
}

std::string buildOpenApiSpec() {
    Json::Value spec;
    spec["openapi"] = "3.0.0";
    spec["info"]["title"] = "S3 Storage Service API";
    spec["info"]["version"] = "1.0.0";
    spec["info"]["description"] =
        "File storage microservice for distributed task-management system.";

    Json::Value components;
    components["schemas"]["SuccessResponse"]["type"] = "object";
    components["schemas"]["SuccessResponse"]["properties"]["success"]["type"] =
        "boolean";
    components["schemas"]["SuccessResponse"]["properties"]["success"]
               ["example"] = true;
    components["schemas"]["SuccessResponse"]["properties"]["data"]["type"] =
        "object";

    components["schemas"]["ErrorResponse"]["type"] = "object";
    components["schemas"]["ErrorResponse"]["properties"]["success"]["type"] =
        "boolean";
    components["schemas"]["ErrorResponse"]["properties"]["success"]
               ["example"] = false;
    components["schemas"]["ErrorResponse"]["properties"]["error"]["type"] =
        "object";
    components["schemas"]["ErrorResponse"]["properties"]["error"]["properties"]
               ["code"]["type"] = "string";
    components["schemas"]["ErrorResponse"]["properties"]["error"]["properties"]
               ["message"]["type"] = "string";

    components["schemas"]["HealthResponse"]["type"] = "object";
    components["schemas"]["HealthResponse"]["properties"]["status"]["type"] =
        "string";
    components["schemas"]["HealthResponse"]["properties"]["database"]["type"] =
        "string";
    components["schemas"]["HealthResponse"]["properties"]["storage"]["type"] =
        "string";

    components["securitySchemes"]["X-User-Id"]["type"] = "apiKey";
    components["securitySchemes"]["X-User-Id"]["in"] = "header";
    components["securitySchemes"]["X-User-Id"]["name"] = "X-User-Id";
    components["securitySchemes"]["X-User-Id"]["description"] =
        "User UUID from API Gateway (required for protected endpoints)";

    Json::Value userSecurity;
    userSecurity["X-User-Id"] = Json::arrayValue;

    spec["components"] = components;

    Json::Value paths;

    // GET /health — no auth
    paths["/health"]["get"]["summary"] = "Health check";
    paths["/health"]["get"]["description"] =
        "Returns 200 when DB and storage are ready, 503 when degraded.";
    paths["/health"]["get"]["operationId"] = "getHealth";
    paths["/health"]["get"]["tags"] = Json::arrayValue;
    paths["/health"]["get"]["tags"].append("Health");
    paths["/health"]["get"]["responses"]["200"]["description"] = "OK";
    paths["/health"]["get"]["responses"]["200"]["content"]["application/json"]
         ["schema"]["$ref"] = "#/components/schemas/HealthResponse";
    paths["/health"]["get"]["responses"]["503"]["description"] = "Degraded";
    paths["/health"]["get"]["responses"]["503"]["content"]["application/json"]
         ["schema"]["$ref"] = "#/components/schemas/HealthResponse";

    // POST /files/buckets/create
    paths["/files/buckets/create"]["post"]["summary"] = "Create bucket";
    paths["/files/buckets/create"]["post"]["operationId"] = "createBucket";
    paths["/files/buckets/create"]["post"]["tags"] = Json::arrayValue;
    paths["/files/buckets/create"]["post"]["tags"].append("Buckets");
    paths["/files/buckets/create"]["post"]["security"] = Json::arrayValue;
    paths["/files/buckets/create"]["post"]["security"].append(userSecurity);
    paths["/files/buckets/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["type"] = "object";
    paths["/files/buckets/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["required"] = Json::arrayValue;
    paths["/files/buckets/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["required"].append("name");
    paths["/files/buckets/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["properties"]["name"]["type"] =
        "string";
    paths["/files/buckets/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["properties"]["description"]["type"] =
        "string";
    paths["/files/buckets/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["properties"]["isPublic"]["type"] =
        "boolean";
    paths["/files/buckets/create"]["post"]["responses"]["201"]["description"] =
        "Created";
    paths["/files/buckets/create"]["post"]["responses"]["201"]["content"]
         ["application/json"]["schema"]["$ref"] =
        "#/components/schemas/SuccessResponse";
    paths["/files/buckets/create"]["post"]["responses"]["400"]["description"] =
        "Bad Request";
    paths["/files/buckets/create"]["post"]["responses"]["401"]["description"] =
        "Unauthorized (missing X-User-Id)";
    addErrorResponses(paths["/files/buckets/create"]["post"]);

    // GET /files/buckets/list
    paths["/files/buckets/list"]["get"]["summary"] = "List buckets";
    paths["/files/buckets/list"]["get"]["operationId"] = "listBuckets";
    paths["/files/buckets/list"]["get"]["tags"] = Json::arrayValue;
    paths["/files/buckets/list"]["get"]["tags"].append("Buckets");
    paths["/files/buckets/list"]["get"]["security"] = Json::arrayValue;
    paths["/files/buckets/list"]["get"]["security"].append(userSecurity);
    paths["/files/buckets/list"]["get"]["responses"]["200"]["description"] =
        "OK";
    paths["/files/buckets/list"]["get"]["responses"]["200"]["content"]
         ["application/json"]["schema"]["$ref"] =
        "#/components/schemas/SuccessResponse";
    paths["/files/buckets/list"]["get"]["responses"]["401"]["description"] =
        "Unauthorized (missing X-User-Id)";
    addErrorResponses(paths["/files/buckets/list"]["get"]);

    // POST /files/folders/create
    paths["/files/folders/create"]["post"]["summary"] = "Create folder";
    paths["/files/folders/create"]["post"]["operationId"] = "createFolder";
    paths["/files/folders/create"]["post"]["tags"] = Json::arrayValue;
    paths["/files/folders/create"]["post"]["tags"].append("Folders");
    paths["/files/folders/create"]["post"]["security"] = Json::arrayValue;
    paths["/files/folders/create"]["post"]["security"].append(userSecurity);
    paths["/files/folders/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["type"] = "object";
    paths["/files/folders/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["required"] = Json::arrayValue;
    paths["/files/folders/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["required"].append("bucketId");
    paths["/files/folders/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["required"].append("name");
    paths["/files/folders/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["properties"]["bucketId"]["type"] =
        "string";
    paths["/files/folders/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["properties"]["bucketId"]["format"] =
        "uuid";
    paths["/files/folders/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["properties"]["bucketId"]["example"] =
        "";
    paths["/files/folders/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["properties"]["bucketId"]["default"] =
        "";
    paths["/files/folders/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["properties"]["name"]["type"] =
        "string";
    paths["/files/folders/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["properties"]["parentFolderId"]
         ["type"] = "string";
    paths["/files/folders/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["properties"]["parentFolderId"]
         ["format"] = "uuid";
    paths["/files/folders/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["properties"]["parentFolderId"]
         ["example"] = "";
    paths["/files/folders/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["properties"]["parentFolderId"]
         ["default"] = "";
    paths["/files/folders/create"]["post"]["responses"]["201"]["description"] =
        "Created";
    paths["/files/folders/create"]["post"]["responses"]["201"]["content"]
         ["application/json"]["schema"]["$ref"] =
        "#/components/schemas/SuccessResponse";
    paths["/files/folders/create"]["post"]["responses"]["400"]["description"] =
        "Bad Request";
    paths["/files/folders/create"]["post"]["responses"]["401"]["description"] =
        "Unauthorized (missing X-User-Id)";
    paths["/files/folders/create"]["post"]["responses"]["404"]["description"] =
        "Not Found";
    addErrorResponses(paths["/files/folders/create"]["post"]);

    // GET /files/list
    paths["/files/list"]["get"]["summary"] = "List files and folders";
    paths["/files/list"]["get"]["operationId"] = "listFiles";
    paths["/files/list"]["get"]["tags"] = Json::arrayValue;
    paths["/files/list"]["get"]["tags"].append("Files");
    paths["/files/list"]["get"]["security"] = Json::arrayValue;
    paths["/files/list"]["get"]["security"].append(userSecurity);
    paths["/files/list"]["get"]["parameters"] = Json::arrayValue;
    paths["/files/list"]["get"]["parameters"][0]["name"] = "bucket_id";
    paths["/files/list"]["get"]["parameters"][0]["in"] = "query";
    paths["/files/list"]["get"]["parameters"][0]["required"] = true;
    paths["/files/list"]["get"]["parameters"][0]["schema"]["type"] = "string";
    paths["/files/list"]["get"]["parameters"][0]["schema"]["format"] = "uuid";
    paths["/files/list"]["get"]["parameters"][0]["schema"]["example"] = "";
    paths["/files/list"]["get"]["parameters"][0]["schema"]["default"] = "";
    paths["/files/list"]["get"]["parameters"][1]["name"] = "parent_folder_id";
    paths["/files/list"]["get"]["parameters"][1]["in"] = "query";
    paths["/files/list"]["get"]["parameters"][1]["required"] = false;
    paths["/files/list"]["get"]["parameters"][1]["schema"]["type"] = "string";
    paths["/files/list"]["get"]["parameters"][1]["schema"]["format"] = "uuid";
    paths["/files/list"]["get"]["parameters"][1]["schema"]["example"] = "";
    paths["/files/list"]["get"]["parameters"][1]["schema"]["default"] = "";
    paths["/files/list"]["get"]["responses"]["200"]["description"] = "OK";
    paths["/files/list"]["get"]["responses"]["200"]["content"]
         ["application/json"]["schema"]["$ref"] =
        "#/components/schemas/SuccessResponse";
    paths["/files/list"]["get"]["responses"]["400"]["description"] =
        "Bad Request";
    paths["/files/list"]["get"]["responses"]["401"]["description"] =
        "Unauthorized (missing X-User-Id)";
    addErrorResponses(paths["/files/list"]["get"]);

    // POST /files/upload
    paths["/files/upload"]["post"]["summary"] = "Upload file";
    paths["/files/upload"]["post"]["operationId"] = "uploadFile";
    paths["/files/upload"]["post"]["tags"] = Json::arrayValue;
    paths["/files/upload"]["post"]["tags"].append("Files");
    paths["/files/upload"]["post"]["security"] = Json::arrayValue;
    paths["/files/upload"]["post"]["security"].append(userSecurity);
    paths["/files/upload"]["post"]["requestBody"]["content"]["multipart/form-data"]
         ["schema"]["type"] = "object";
    paths["/files/upload"]["post"]["requestBody"]["content"]["multipart/form-data"]
         ["schema"]["required"] = Json::arrayValue;
    paths["/files/upload"]["post"]["requestBody"]["content"]["multipart/form-data"]
         ["schema"]["required"].append("file");
    paths["/files/upload"]["post"]["requestBody"]["content"]["multipart/form-data"]
         ["schema"]["required"].append("bucket_id");
    paths["/files/upload"]["post"]["requestBody"]["content"]["multipart/form-data"]
         ["schema"]["properties"]["file"]["type"] = "string";
    paths["/files/upload"]["post"]["requestBody"]["content"]["multipart/form-data"]
         ["schema"]["properties"]["file"]["format"] = "binary";
    paths["/files/upload"]["post"]["requestBody"]["content"]["multipart/form-data"]
         ["schema"]["properties"]["file"]["description"] = "File to upload";
    paths["/files/upload"]["post"]["requestBody"]["content"]["multipart/form-data"]
         ["encoding"]["file"]["contentType"] = "application/octet-stream";
    paths["/files/upload"]["post"]["requestBody"]["content"]["multipart/form-data"]
         ["schema"]["properties"]["bucket_id"]["type"] = "string";
    paths["/files/upload"]["post"]["requestBody"]["content"]["multipart/form-data"]
         ["schema"]["properties"]["bucket_id"]["format"] = "uuid";
    paths["/files/upload"]["post"]["requestBody"]["content"]["multipart/form-data"]
         ["schema"]["properties"]["bucket_id"]["example"] = "";
    paths["/files/upload"]["post"]["requestBody"]["content"]["multipart/form-data"]
         ["schema"]["properties"]["bucket_id"]["default"] = "";
    paths["/files/upload"]["post"]["requestBody"]["content"]["multipart/form-data"]
         ["schema"]["properties"]["parent_folder_id"]["type"] = "string";
    paths["/files/upload"]["post"]["requestBody"]["content"]["multipart/form-data"]
         ["schema"]["properties"]["parent_folder_id"]["format"] = "uuid";
    paths["/files/upload"]["post"]["requestBody"]["content"]["multipart/form-data"]
         ["schema"]["properties"]["parent_folder_id"]["example"] = "";
    paths["/files/upload"]["post"]["requestBody"]["content"]["multipart/form-data"]
         ["schema"]["properties"]["parent_folder_id"]["default"] = "";
    paths["/files/upload"]["post"]["requestBody"]["content"]["multipart/form-data"]
         ["schema"]["properties"]["parent_folder_id"]["description"] =
        "Optional. UUID of parent folder. Leave empty for root.";
    paths["/files/upload"]["post"]["responses"]["201"]["description"] =
        "Created";
    paths["/files/upload"]["post"]["responses"]["201"]["content"]
         ["application/json"]["schema"]["$ref"] =
        "#/components/schemas/SuccessResponse";
    paths["/files/upload"]["post"]["responses"]["400"]["description"] =
        "Bad Request";
    paths["/files/upload"]["post"]["responses"]["401"]["description"] =
        "Unauthorized (missing X-User-Id)";
    paths["/files/upload"]["post"]["responses"]["413"]["description"] =
        "Payload Too Large";
    paths["/files/upload"]["post"]["responses"]["415"]["description"] =
        "Unsupported Media Type";
    paths["/files/upload"]["post"]["responses"]["507"]["description"] =
        "Insufficient Storage";
    addErrorResponses(paths["/files/upload"]["post"]);

    // GET /files/download
    paths["/files/download"]["get"]["summary"] = "Download file";
    paths["/files/download"]["get"]["operationId"] = "downloadFile";
    paths["/files/download"]["get"]["tags"] = Json::arrayValue;
    paths["/files/download"]["get"]["tags"].append("Files");
    paths["/files/download"]["get"]["security"] = Json::arrayValue;
    paths["/files/download"]["get"]["security"].append(userSecurity);
    paths["/files/download"]["get"]["parameters"] = Json::arrayValue;
    paths["/files/download"]["get"]["parameters"][0]["name"] = "file_id";
    paths["/files/download"]["get"]["parameters"][0]["in"] = "query";
    paths["/files/download"]["get"]["parameters"][0]["required"] = true;
    paths["/files/download"]["get"]["parameters"][0]["schema"]["type"] =
        "string";
    paths["/files/download"]["get"]["parameters"][0]["schema"]["format"] =
        "uuid";
    paths["/files/download"]["get"]["parameters"][0]["schema"]["example"] = "";
    paths["/files/download"]["get"]["parameters"][0]["schema"]["default"] = "";
    paths["/files/download"]["get"]["responses"]["200"]["description"] = "OK";
    paths["/files/download"]["get"]["responses"]["200"]["content"]
         ["application/octet-stream"]["schema"]["type"] = "string";
    paths["/files/download"]["get"]["responses"]["200"]["content"]
         ["application/octet-stream"]["schema"]["format"] = "binary";
    paths["/files/download"]["get"]["responses"]["400"]["description"] =
        "Bad Request";
    paths["/files/download"]["get"]["responses"]["401"]["description"] =
        "Unauthorized (missing X-User-Id)";
    paths["/files/download"]["get"]["responses"]["404"]["description"] =
        "Not Found";
    addErrorResponses(paths["/files/download"]["get"]);

    // POST /files/move
    paths["/files/move"]["post"]["summary"] = "Move file or folder";
    paths["/files/move"]["post"]["description"] =
        "After a successful move, clients should re-fetch GET /files/list for "
        "both the source and destination buckets to reflect the change. The "
        "list endpoint returns Cache-Control: no-store to prevent stale caches.";
    paths["/files/move"]["post"]["operationId"] = "moveFile";
    paths["/files/move"]["post"]["tags"] = Json::arrayValue;
    paths["/files/move"]["post"]["tags"].append("Files");
    paths["/files/move"]["post"]["security"] = Json::arrayValue;
    paths["/files/move"]["post"]["security"].append(userSecurity);
    paths["/files/move"]["post"]["requestBody"]["content"]["application/json"]
         ["schema"]["type"] = "object";
    paths["/files/move"]["post"]["requestBody"]["content"]["application/json"]
         ["schema"]["required"] = Json::arrayValue;
    paths["/files/move"]["post"]["requestBody"]["content"]["application/json"]
         ["schema"]["required"].append("fileId");
    paths["/files/move"]["post"]["requestBody"]["content"]["application/json"]
         ["schema"]["properties"]["fileId"]["type"] = "string";
    paths["/files/move"]["post"]["requestBody"]["content"]["application/json"]
         ["schema"]["properties"]["fileId"]["format"] = "uuid";
    paths["/files/move"]["post"]["requestBody"]["content"]["application/json"]
         ["schema"]["properties"]["fileId"]["example"] = "";
    paths["/files/move"]["post"]["requestBody"]["content"]["application/json"]
         ["schema"]["properties"]["fileId"]["default"] = "";
    paths["/files/move"]["post"]["requestBody"]["content"]["application/json"]
         ["schema"]["properties"]["newParentFolderId"]["type"] = "string";
    paths["/files/move"]["post"]["requestBody"]["content"]["application/json"]
         ["schema"]["properties"]["newParentFolderId"]["format"] = "uuid";
    paths["/files/move"]["post"]["requestBody"]["content"]["application/json"]
         ["schema"]["properties"]["newParentFolderId"]["example"] = "";
    paths["/files/move"]["post"]["requestBody"]["content"]["application/json"]
         ["schema"]["properties"]["newParentFolderId"]["default"] = "";
    paths["/files/move"]["post"]["requestBody"]["content"]["application/json"]
         ["schema"]["properties"]["newParentFolderId"]["description"] =
        "Optional. New parent folder ID. For cross-bucket: folder in newBucketId.";
    paths["/files/move"]["post"]["requestBody"]["content"]["application/json"]
         ["schema"]["properties"]["newBucketId"]["type"] = "string";
    paths["/files/move"]["post"]["requestBody"]["content"]["application/json"]
         ["schema"]["properties"]["newBucketId"]["format"] = "uuid";
    paths["/files/move"]["post"]["requestBody"]["content"]["application/json"]
         ["schema"]["properties"]["newBucketId"]["example"] = "";
    paths["/files/move"]["post"]["requestBody"]["content"]["application/json"]
         ["schema"]["properties"]["newBucketId"]["default"] = "";
    paths["/files/move"]["post"]["requestBody"]["content"]["application/json"]
         ["schema"]["properties"]["newBucketId"]["description"] =
        "Optional. Destination bucket for cross-bucket move. If provided, moves file "
        "to this bucket. newParentFolderId optional (folder in that bucket). If "
        "omitted, same-bucket move.";
    paths["/files/move"]["post"]["responses"]["200"]["description"] = "OK";
    paths["/files/move"]["post"]["responses"]["200"]["content"]
         ["application/json"]["schema"]["$ref"] =
        "#/components/schemas/SuccessResponse";
    paths["/files/move"]["post"]["responses"]["400"]["description"] =
        "Bad Request (e.g. folder cross-bucket not supported)";
    paths["/files/move"]["post"]["responses"]["401"]["description"] =
        "Unauthorized (missing X-User-Id)";
    paths["/files/move"]["post"]["responses"]["403"]["description"] =
        "Forbidden (quota exceeded)";
    paths["/files/move"]["post"]["responses"]["404"]["description"] =
        "Not Found (file, bucket, or folder)";
    paths["/files/move"]["post"]["responses"]["507"]["description"] =
        "Insufficient Storage";
    addErrorResponses(paths["/files/move"]["post"]);

    // POST /files/share/create
    paths["/files/share/create"]["post"]["summary"] = "Create shared link";
    paths["/files/share/create"]["post"]["operationId"] = "createShareLink";
    paths["/files/share/create"]["post"]["tags"] = Json::arrayValue;
    paths["/files/share/create"]["post"]["tags"].append("Share");
    paths["/files/share/create"]["post"]["security"] = Json::arrayValue;
    paths["/files/share/create"]["post"]["security"].append(userSecurity);
    paths["/files/share/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["type"] = "object";
    paths["/files/share/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["required"] = Json::arrayValue;
    paths["/files/share/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["required"].append("fileId");
    paths["/files/share/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["properties"]["fileId"]["type"] =
        "string";
    paths["/files/share/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["properties"]["fileId"]["format"] =
        "uuid";
    paths["/files/share/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["properties"]["fileId"]["example"] =
        "";
    paths["/files/share/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["properties"]["fileId"]["default"] =
        "";
    paths["/files/share/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["properties"]["expiresAt"]["type"] =
        "string";
    paths["/files/share/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["properties"]["expiresAt"]["format"] =
        "date-time";
    paths["/files/share/create"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["properties"]["maxDownloads"]["type"] =
        "integer";
    paths["/files/share/create"]["post"]["responses"]["201"]["description"] =
        "Created";
    paths["/files/share/create"]["post"]["responses"]["201"]["content"]
         ["application/json"]["schema"]["$ref"] =
        "#/components/schemas/SuccessResponse";
    paths["/files/share/create"]["post"]["responses"]["400"]["description"] =
        "Bad Request";
    paths["/files/share/create"]["post"]["responses"]["401"]["description"] =
        "Unauthorized (missing X-User-Id)";
    paths["/files/share/create"]["post"]["responses"]["404"]["description"] =
        "Not Found";
    addErrorResponses(paths["/files/share/create"]["post"]);

    // GET /files/shared/{token} — no auth
    paths["/files/shared/{token}"]["get"]["summary"] =
        "Download file by shared link token";
    paths["/files/shared/{token}"]["get"]["operationId"] = "downloadSharedFile";
    paths["/files/shared/{token}"]["get"]["tags"] = Json::arrayValue;
    paths["/files/shared/{token}"]["get"]["tags"].append("Share");
    paths["/files/shared/{token}"]["get"]["security"] = Json::arrayValue;
    paths["/files/shared/{token}"]["get"]["parameters"] = Json::arrayValue;
    paths["/files/shared/{token}"]["get"]["parameters"][0]["name"] = "token";
    paths["/files/shared/{token}"]["get"]["parameters"][0]["in"] = "path";
    paths["/files/shared/{token}"]["get"]["parameters"][0]["required"] = true;
    paths["/files/shared/{token}"]["get"]["parameters"][0]["schema"]["type"] =
        "string";
    paths["/files/shared/{token}"]["get"]["parameters"][0]["description"] =
        "Shared link token from POST /files/share/create";
    paths["/files/shared/{token}"]["get"]["responses"]["200"]["description"] =
        "OK";
    paths["/files/shared/{token}"]["get"]["responses"]["200"]["content"]
         ["application/octet-stream"]["schema"]["type"] = "string";
    paths["/files/shared/{token}"]["get"]["responses"]["200"]["content"]
         ["application/octet-stream"]["schema"]["format"] = "binary";
    paths["/files/shared/{token}"]["get"]["responses"]["403"]["description"] =
        "Forbidden (link revoked)";
    paths["/files/shared/{token}"]["get"]["responses"]["403"]["content"]
         ["application/json"]["schema"]["$ref"] =
        "#/components/schemas/ErrorResponse";
    paths["/files/shared/{token}"]["get"]["responses"]["404"]["description"] =
        "Not Found (invalid, expired, or exhausted link)";
    paths["/files/shared/{token}"]["get"]["responses"]["404"]["content"]
         ["application/json"]["schema"]["$ref"] =
        "#/components/schemas/ErrorResponse";
    addErrorResponses(paths["/files/shared/{token}"]["get"]);

    // POST /files/delete — deprecated, use DELETE /files/{file_id}
    paths["/files/delete"]["post"]["summary"] =
        "[Deprecated] Soft delete file or folder (use DELETE /files/{file_id})";
    paths["/files/delete"]["post"]["deprecated"] = true;
    paths["/files/delete"]["post"]["operationId"] = "deleteFile";
    paths["/files/delete"]["post"]["tags"] = Json::arrayValue;
    paths["/files/delete"]["post"]["tags"].append("Files");
    paths["/files/delete"]["post"]["security"] = Json::arrayValue;
    paths["/files/delete"]["post"]["security"].append(userSecurity);
    paths["/files/delete"]["post"]["requestBody"]["content"]["application/json"]
         ["schema"]["type"] = "object";
    paths["/files/delete"]["post"]["requestBody"]["content"]["application/json"]
         ["schema"]["required"] = Json::arrayValue;
    paths["/files/delete"]["post"]["requestBody"]["content"]["application/json"]
         ["schema"]["required"].append("fileId");
    paths["/files/delete"]["post"]["requestBody"]["content"]["application/json"]
         ["schema"]["properties"]["fileId"]["type"] = "string";
    paths["/files/delete"]["post"]["requestBody"]["content"]["application/json"]
         ["schema"]["properties"]["fileId"]["format"] = "uuid";
    paths["/files/delete"]["post"]["requestBody"]["content"]["application/json"]
         ["schema"]["properties"]["fileId"]["example"] = "";
    paths["/files/delete"]["post"]["requestBody"]["content"]["application/json"]
         ["schema"]["properties"]["fileId"]["default"] = "";
    paths["/files/delete"]["post"]["responses"]["200"]["description"] = "OK";
    paths["/files/delete"]["post"]["responses"]["200"]["content"]
         ["application/json"]["schema"]["$ref"] =
        "#/components/schemas/SuccessResponse";
    paths["/files/delete"]["post"]["responses"]["400"]["description"] =
        "Bad Request";
    paths["/files/delete"]["post"]["responses"]["401"]["description"] =
        "Unauthorized (missing X-User-Id)";
    paths["/files/delete"]["post"]["responses"]["404"]["description"] =
        "Not Found";
    addErrorResponses(paths["/files/delete"]["post"]);

    // DELETE /files/{file_id} — REST-style soft delete
    paths["/files/{file_id}"]["delete"]["summary"] =
        "Soft delete file or folder (REST)";
    paths["/files/{file_id}"]["delete"]["operationId"] = "deleteFileRest";
    paths["/files/{file_id}"]["delete"]["tags"] = Json::arrayValue;
    paths["/files/{file_id}"]["delete"]["tags"].append("Files");
    paths["/files/{file_id}"]["delete"]["security"] = Json::arrayValue;
    paths["/files/{file_id}"]["delete"]["security"].append(userSecurity);
    paths["/files/{file_id}"]["delete"]["parameters"] = Json::arrayValue;
    paths["/files/{file_id}"]["delete"]["parameters"][0]["name"] = "file_id";
    paths["/files/{file_id}"]["delete"]["parameters"][0]["in"] = "path";
    paths["/files/{file_id}"]["delete"]["parameters"][0]["required"] = true;
    paths["/files/{file_id}"]["delete"]["parameters"][0]["schema"]["type"] =
        "string";
    paths["/files/{file_id}"]["delete"]["parameters"][0]["schema"]["format"] =
        "uuid";
    paths["/files/{file_id}"]["delete"]["parameters"][0]["schema"]["example"] =
        "";
    paths["/files/{file_id}"]["delete"]["parameters"][0]["schema"]["default"] =
        "";
    paths["/files/{file_id}"]["delete"]["responses"]["200"]["description"] =
        "OK";
    paths["/files/{file_id}"]["delete"]["responses"]["200"]["content"]
         ["application/json"]["schema"]["$ref"] =
        "#/components/schemas/SuccessResponse";
    paths["/files/{file_id}"]["delete"]["responses"]["400"]["description"] =
        "Bad Request";
    paths["/files/{file_id}"]["delete"]["responses"]["401"]["description"] =
        "Unauthorized (missing X-User-Id)";
    paths["/files/{file_id}"]["delete"]["responses"]["404"]["description"] =
        "Not Found";
    addErrorResponses(paths["/files/{file_id}"]["delete"]);

    // DELETE /files/buckets/{bucket_id} — REST-style soft delete
    paths["/files/buckets/{bucket_id}"]["delete"]["summary"] =
        "Soft delete bucket (REST)";
    paths["/files/buckets/{bucket_id}"]["delete"]["operationId"] =
        "deleteBucketRest";
    paths["/files/buckets/{bucket_id}"]["delete"]["tags"] = Json::arrayValue;
    paths["/files/buckets/{bucket_id}"]["delete"]["tags"].append("Buckets");
    paths["/files/buckets/{bucket_id}"]["delete"]["security"] =
        Json::arrayValue;
    paths["/files/buckets/{bucket_id}"]["delete"]["security"].append(
        userSecurity);
    paths["/files/buckets/{bucket_id}"]["delete"]["parameters"] =
        Json::arrayValue;
    paths["/files/buckets/{bucket_id}"]["delete"]["parameters"][0]["name"] =
        "bucket_id";
    paths["/files/buckets/{bucket_id}"]["delete"]["parameters"][0]["in"] =
        "path";
    paths["/files/buckets/{bucket_id}"]["delete"]["parameters"][0]["required"] =
        true;
    paths["/files/buckets/{bucket_id}"]["delete"]["parameters"][0]["schema"]
         ["type"] = "string";
    paths["/files/buckets/{bucket_id}"]["delete"]["parameters"][0]["schema"]
         ["format"] = "uuid";
    paths["/files/buckets/{bucket_id}"]["delete"]["parameters"][0]["schema"]
         ["example"] = "";
    paths["/files/buckets/{bucket_id}"]["delete"]["parameters"][0]["schema"]
         ["default"] = "";
    paths["/files/buckets/{bucket_id}"]["delete"]["responses"]["200"]
         ["description"] = "OK";
    paths["/files/buckets/{bucket_id}"]["delete"]["responses"]["200"]
         ["content"]["application/json"]["schema"]["$ref"] =
        "#/components/schemas/SuccessResponse";
    paths["/files/buckets/{bucket_id}"]["delete"]["responses"]["400"]
         ["description"] = "Bad Request";
    paths["/files/buckets/{bucket_id}"]["delete"]["responses"]["401"]
         ["description"] = "Unauthorized (missing X-User-Id)";
    paths["/files/buckets/{bucket_id}"]["delete"]["responses"]["404"]
         ["description"] = "Not Found";
    addErrorResponses(paths["/files/buckets/{bucket_id}"]["delete"]);

    // POST /files/buckets/{bucket_id}/deduplicate
    paths["/files/buckets/{bucket_id}/deduplicate"]["post"]["summary"] =
        "Deduplicate files in bucket";
    paths["/files/buckets/{bucket_id}/deduplicate"]["post"]["description"] =
        "Removes duplicates (same name, parent_folder_id, size), keeps newest "
        "version, soft-deletes others, deletes from disk.";
    paths["/files/buckets/{bucket_id}/deduplicate"]["post"]["operationId"] =
        "deduplicateBucket";
    paths["/files/buckets/{bucket_id}/deduplicate"]["post"]["tags"] =
        Json::arrayValue;
    paths["/files/buckets/{bucket_id}/deduplicate"]["post"]["tags"].append(
        "Buckets");
    paths["/files/buckets/{bucket_id}/deduplicate"]["post"]["security"] =
        Json::arrayValue;
    paths["/files/buckets/{bucket_id}/deduplicate"]["post"]["security"]
        .append(userSecurity);
    paths["/files/buckets/{bucket_id}/deduplicate"]["post"]["parameters"] =
        Json::arrayValue;
    paths["/files/buckets/{bucket_id}/deduplicate"]["post"]["parameters"][0]
         ["name"] = "bucket_id";
    paths["/files/buckets/{bucket_id}/deduplicate"]["post"]["parameters"][0]
         ["in"] = "path";
    paths["/files/buckets/{bucket_id}/deduplicate"]["post"]["parameters"][0]
         ["required"] = true;
    paths["/files/buckets/{bucket_id}/deduplicate"]["post"]["parameters"][0]
         ["schema"]["type"] = "string";
    paths["/files/buckets/{bucket_id}/deduplicate"]["post"]["parameters"][0]
         ["schema"]["format"] = "uuid";
    paths["/files/buckets/{bucket_id}/deduplicate"]["post"]["parameters"][0]
         ["schema"]["example"] = "";
    paths["/files/buckets/{bucket_id}/deduplicate"]["post"]["parameters"][0]
         ["schema"]["default"] = "";
    paths["/files/buckets/{bucket_id}/deduplicate"]["post"]["responses"]["200"]
         ["description"] = "OK (data: removedCount, removedSize)";
    paths["/files/buckets/{bucket_id}/deduplicate"]["post"]["responses"]["200"]
         ["content"]["application/json"]["schema"]["$ref"] =
        "#/components/schemas/SuccessResponse";
    paths["/files/buckets/{bucket_id}/deduplicate"]["post"]["responses"]["400"]
         ["description"] = "Bad Request";
    paths["/files/buckets/{bucket_id}/deduplicate"]["post"]["responses"]["401"]
         ["description"] = "Unauthorized (missing X-User-Id)";
    paths["/files/buckets/{bucket_id}/deduplicate"]["post"]["responses"]["404"]
         ["description"] = "Not Found";
    addErrorResponses(
        paths["/files/buckets/{bucket_id}/deduplicate"]["post"]);

    // POST /files/buckets/delete — deprecated, use DELETE /files/buckets/{bucket_id}
    paths["/files/buckets/delete"]["post"]["summary"] =
        "[Deprecated] Soft delete bucket (use DELETE /files/buckets/{bucket_id})";
    paths["/files/buckets/delete"]["post"]["deprecated"] = true;
    paths["/files/buckets/delete"]["post"]["operationId"] = "deleteBucket";
    paths["/files/buckets/delete"]["post"]["tags"] = Json::arrayValue;
    paths["/files/buckets/delete"]["post"]["tags"].append("Buckets");
    paths["/files/buckets/delete"]["post"]["security"] = Json::arrayValue;
    paths["/files/buckets/delete"]["post"]["security"].append(userSecurity);
    paths["/files/buckets/delete"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["type"] = "object";
    paths["/files/buckets/delete"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["required"] = Json::arrayValue;
    paths["/files/buckets/delete"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["required"].append("bucketId");
    paths["/files/buckets/delete"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["properties"]["bucketId"]["type"] =
        "string";
    paths["/files/buckets/delete"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["properties"]["bucketId"]["format"] =
        "uuid";
    paths["/files/buckets/delete"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["properties"]["bucketId"]["example"] =
        "";
    paths["/files/buckets/delete"]["post"]["requestBody"]["content"]
         ["application/json"]["schema"]["properties"]["bucketId"]["default"] =
        "";
    paths["/files/buckets/delete"]["post"]["responses"]["200"]["description"] =
        "OK";
    paths["/files/buckets/delete"]["post"]["responses"]["200"]["content"]
         ["application/json"]["schema"]["$ref"] =
        "#/components/schemas/SuccessResponse";
    paths["/files/buckets/delete"]["post"]["responses"]["400"]["description"] =
        "Bad Request";
    paths["/files/buckets/delete"]["post"]["responses"]["401"]["description"] =
        "Unauthorized (missing X-User-Id)";
    paths["/files/buckets/delete"]["post"]["responses"]["404"]["description"] =
        "Not Found";
    addErrorResponses(paths["/files/buckets/delete"]["post"]);

    spec["paths"] = paths;

    Json::StreamWriterBuilder wbuilder;
    wbuilder["indentation"] = "  ";
    return Json::writeString(wbuilder, spec);
}

}  // namespace

void SwaggerController::getSpec(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) {
    if (!isSwaggerEnabled()) {
        auto resp = drogon::HttpResponse::newHttpResponse();
        resp->setStatusCode(drogon::k404NotFound);
        callback(resp);
        return;
    }
    std::string spec = buildOpenApiSpec();
    auto resp = drogon::HttpResponse::newHttpResponse();
    resp->setBody(spec);
    resp->addHeader("Content-Type", "application/json");
    callback(resp);
}

void SwaggerController::getUi(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) {
    if (!isSwaggerEnabled()) {
        auto resp = drogon::HttpResponse::newHttpResponse();
        resp->setStatusCode(drogon::k404NotFound);
        callback(resp);
        return;
    }
    const char* html = R"html(<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>S3 Storage Service API</title>
    <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css">
</head>
<body>
    <div id="swagger-ui"></div>
    <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
    <script>
        SwaggerUIBundle({
            url: '/swagger.json',
            dom_id: '#swagger-ui',
            presets: [
                SwaggerUIBundle.presets.apis,
                SwaggerUIBundle.SwaggerUIStandalonePreset
            ]
        });
    </script>
</body>
</html>
)html";
    auto resp = drogon::HttpResponse::newHttpResponse();
    resp->setBody(html);
    resp->addHeader("Content-Type", "text/html");
    callback(resp);
}

} 
