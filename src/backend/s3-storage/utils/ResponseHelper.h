/**
Build standard JSON responses for S3 Storage Service API
Format: {"success": true/false, "data"/"error": {...}}
Echoes X-Request-Id from request in response when present.
 */

#pragma once

#include <drogon/drogon.h>
#include <json/json.h>
#include <functional>
#include <string>

namespace s3 {

//Helpers for building success and error JSON responses.

class ResponseHelper {
public:
    //Send success response with data.

    template <typename Callback>
    static void sendSuccess(
        const drogon::HttpRequestPtr& req,
        Json::Value&& data,
        Callback&& callback,
        int statusCode = 200) {
        auto resp = buildSuccess(req, std::move(data), statusCode);
        callback(resp);
    }

    //Send error response.

    template <typename Callback>
    static void sendError(
        const drogon::HttpRequestPtr& req,
        const std::string& code,
        const std::string& message,
        int statusCode,
        Callback&& callback) {
        auto resp = buildError(req, code, message, statusCode);
        callback(resp);
    }

    //Build success HttpResponsePtr (for use when callback is handled elsewhere).

    static drogon::HttpResponsePtr buildSuccess(
        const drogon::HttpRequestPtr& req,
        Json::Value&& data,
        int statusCode = 200);

   // Build error HttpResponsePtr (for use when callback is handled * elsewhere).
    
    static drogon::HttpResponsePtr buildError(
        const drogon::HttpRequestPtr& req,
        const std::string& code,
        const std::string& message,
        int statusCode);
};

} 

