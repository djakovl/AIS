/*
 File model — maps files table to C++ struct.
 Архивариус — data representation for file/folder entities.
 */

#pragma once

#include <drogon/orm/Row.h>
#include <drogon/orm/Field.h>
#include <json/json.h>
#include <cstdint>
#include <string>

namespace s3 {

//File or folder entity model
struct File {
    std::string id;
    std::string bucketId;
    std::string userId;
    std::string parentFolderId;
    std::string name;
    std::string path;
    int64_t size = 0;
    std::string mimeType;
    std::string storageKey;
    bool isFolder = false;
    bool isPublic = false;
    int downloadCount = 0;
    std::string createdAt;
    std::string updatedAt;

    //Serialize to JSON for API responses (camelCase keys).

    Json::Value toJson() const {
        Json::Value j;
        j["id"] = id;
        j["bucketId"] = bucketId;
        j["userId"] = userId;
        j["parentFolderId"] = parentFolderId.empty() ? Json::Value() : parentFolderId;
        j["name"] = name;
        j["path"] = path;
        j["size"] = static_cast<Json::Int64>(size);
        j["mimeType"] = mimeType;
        j["storageKey"] = storageKey;
        j["isFolder"] = isFolder;
        j["isPublic"] = isPublic;
        j["downloadCount"] = downloadCount;
        j["createdAt"] = createdAt;
        j["updatedAt"] = updatedAt;
        return j;
    }

    //Create File from database row (snake_case columns).
    static File fromRow(const drogon::orm::Row& r) {
        File f;
        f.id = r["id"].as<std::string>();
        f.bucketId = r["bucket_id"].as<std::string>();
        f.userId = r["user_id"].as<std::string>();
        f.parentFolderId = r["parent_folder_id"].isNull()
                               ? ""
                               : r["parent_folder_id"].as<std::string>();
        f.name = r["name"].as<std::string>();
        f.path = r["path"].as<std::string>();
        f.size = r["size"].as<long long>();
        f.mimeType = r["mime_type"].isNull()
                         ? "application/octet-stream"
                         : r["mime_type"].as<std::string>();
        f.storageKey = r["storage_key"].as<std::string>();
        f.isFolder = r["is_folder"].as<bool>();
        f.isPublic = r["is_public"].as<bool>();
        f.downloadCount = r["download_count"].as<int>();
        f.createdAt = r["created_at"].isNull() ? "" : r["created_at"].as<std::string>();
        f.updatedAt = r["updated_at"].isNull() ? "" : r["updated_at"].as<std::string>();
        return f;
    }
};

} 

