#include "utils/Logger.h"
#include <json/json.h>
#include <chrono>
#include <iomanip>
#include <sstream>

namespace s3 {

std::string Logger::toIso8601(std::chrono::system_clock::time_point tp) {
    auto time = std::chrono::system_clock::to_time_t(tp);
    struct tm tmBuf;
    gmtime_r(&time, &tmBuf);
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                  tp.time_since_epoch()) %
              1000;
    std::ostringstream oss;
    oss << std::put_time(&tmBuf, "%Y-%m-%dT%H:%M:%S");
    oss << "." << std::setfill('0') << std::setw(3) << ms.count() << "Z";
    return oss.str();
}

void Logger::log(const std::string& level,
                 const std::string& msg,
                 const std::string& userId,
                 const std::string& requestId) {
    Json::Value obj;
    obj["level"] = level;
    obj["msg"] = msg;
    obj["ts"] = toIso8601(std::chrono::system_clock::now());
    if (!userId.empty()) {
        obj["user_id"] = userId;
    }
    if (!requestId.empty()) {
        obj["request_id"] = requestId;
    }

    Json::StreamWriterBuilder builder;
    builder["indentation"] = "";
    std::string jsonStr = Json::writeString(builder, obj);

    if (level == "info") {
        LOG_INFO << jsonStr;
    } else if (level == "warn") {
        LOG_WARN << jsonStr;
    } else {
        LOG_ERROR << jsonStr;
    }
}

void Logger::info(const std::string& msg,
                  const std::string& userId,
                  const std::string& requestId) {
    log("info", msg, userId, requestId);
}

void Logger::warn(const std::string& msg,
                  const std::string& userId,
                  const std::string& requestId) {
    log("warn", msg, userId, requestId);
}

void Logger::error(const std::string& msg,
                   const std::string& userId,
                   const std::string& requestId) {
    log("error", msg, userId, requestId);
}

std::pair<std::string, std::string> Logger::getContextFromRequest(
    const drogon::HttpRequestPtr& req) {
    if (!req) {
        return {"", ""};
    }
    std::string userId = req->getHeader("x-user-id");
    std::string requestId = req->getHeader("x-request-id");
    return {userId, requestId};
}

}  // namespace s3
