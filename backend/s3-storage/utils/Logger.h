/* 
Async JSON structured logging for S3 Storage Service.
Logs include user_id and request_id when available. Does not log sensitive
data (passwords, tokens, PII). Uses Drogon LOG_* macros with JSON format.
 */

#pragma once

#include <drogon/drogon.h>
#include <json/json.h>
#include <chrono>
#include <string>
#include <utility>

namespace s3 {

class Logger {
public:
    static void info(const std::string& msg,
                     const std::string& userId = {},
                     const std::string& requestId = {});
    static void warn(const std::string& msg,
                    const std::string& userId = {},
                    const std::string& requestId = {});

    static void error(const std::string& msg,
                      const std::string& userId = {},
                      const std::string& requestId = {});


    static std::pair<std::string, std::string> getContextFromRequest(
        const drogon::HttpRequestPtr& req);

private:
    static void log(const std::string& level,
                   const std::string& msg,
                   const std::string& userId,
                   const std::string& requestId);

    static std::string toIso8601(std::chrono::system_clock::time_point tp);
};

}  
