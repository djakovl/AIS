//Bucket model — maps buckets table to C++ struct.
//Архивариус — data representation for bucket entities.
 

#pragma once

#include <drogon/orm/Row.h>
#include <drogon/orm/Field.h>
#include <json/json.h>
#include <cstdint>
#include <string>

namespace s3 {

//Bucket entity model.

struct Bucket {
    std::string id;
    std::string userId;
    std::string name;
    std::string description;
    bool isPublic = false;
    int64_t storageUsed = 0;
    int64_t storageLimit = 10737418240;
    std::string createdAt;
    std::string updatedAt;

    //Serialize to JSON for API responses (camelCase keys).
    Json::Value toJson() const {
        Json::Value j;
        j["id"] = id;
        j["userId"] = userId;
        j["name"] = name;
        j["description"] = description;
        j["isPublic"] = isPublic;
        j["storageUsed"] = static_cast<Json::Int64>(storageUsed);
        j["storageLimit"] = static_cast<Json::Int64>(storageLimit);
        j["createdAt"] = createdAt;
        j["updatedAt"] = updatedAt;
        return j;
    }

    //Create Bucket from database row (snake_case columns).

    static Bucket fromRow(const drogon::orm::Row& r) {
        Bucket b;
        b.id = r["id"].as<std::string>();
        b.userId = r["user_id"].as<std::string>();
        b.name = r["name"].as<std::string>();
        b.description = r["description"].isNull() ? "" : r["description"].as<std::string>();
        b.isPublic = r["is_public"].as<bool>();
        b.storageUsed = r["storage_used"].as<long long>();
        b.storageLimit = r["storage_limit"].as<long long>();
        b.createdAt = r["created_at"].isNull() ? "" : r["created_at"].as<std::string>();
        b.updatedAt = r["updated_at"].isNull() ? "" : r["updated_at"].as<std::string>();
        return b;
    }
};

}  // namespace s3
