/*
SharedLink model — maps shared_links table to C++ struct
Архивариус — data representation for share link entities.
 */

#pragma once

#include <drogon/orm/Row.h>
#include <drogon/orm/Field.h>
#include <json/json.h>
#include <string>

namespace s3 {

//Shared link entity model.

struct SharedLink {
    std::string id;
    std::string fileId;
    std::string userId;
    std::string token;
    std::string expiresAt;
    int maxDownloads = 0;  // 0 = unlimited when NULL in DB
    int downloadCount = 0;
    bool isActive = true;
    std::string createdAt;

//Serialize to JSON for API responses (camelCase keys).
    
    Json::Value toJson() const {
        Json::Value j;
        j["id"] = id;
        j["fileId"] = fileId;
        j["userId"] = userId;
        j["token"] = token;
        j["expiresAt"] = expiresAt.empty() ? Json::Value() : expiresAt;
        j["maxDownloads"] = maxDownloads;
        j["downloadCount"] = downloadCount;
        j["isActive"] = isActive;
        j["createdAt"] = createdAt;
        return j;
    }

    //Create SharedLink from database row (snake_case columns).
    
    static SharedLink fromRow(const drogon::orm::Row& r) {
        SharedLink s;
        s.id = r["id"].as<std::string>();
        s.fileId = r["file_id"].as<std::string>();
        s.userId = r["user_id"].as<std::string>();
        s.token = r["token"].as<std::string>();
        s.expiresAt = r["expires_at"].isNull() ? "" : r["expires_at"].as<std::string>();
        s.maxDownloads = r["max_downloads"].isNull() ? 0 : r["max_downloads"].as<int>();
        s.downloadCount = r["download_count"].as<int>();
        s.isActive = r["is_active"].as<bool>();
        s.createdAt = r["created_at"].isNull() ? "" : r["created_at"].as<std::string>();
        return s;
    }
};

}  
