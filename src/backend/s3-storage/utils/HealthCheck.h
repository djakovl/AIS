/*
 Async health check for S3 Storage Service (DB + disk).
 Логист — observability. Checks PostgreSQL connectivity and storage path writability. Non-blocking, uses async callbacks. Must NOT block event loop.
 */

#pragma once

#include <functional>
#include <json/json.h>
#include <string>

namespace s3 {

struct HealthResult {
    int statusCode{503};
    Json::Value body;
};

class HealthCheck {
public:
    using Callback = std::function<void(HealthResult)>;
    static void checkAsync(Callback&& callback);
    static std::string getStoragePath();
};

} 