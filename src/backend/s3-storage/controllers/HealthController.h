/*
Секретарь — API layer. Returns 200 when DB and storage are ready,
503 when degraded. Non-blocking async handler.
 */

#pragma once

#include <drogon/drogon.h>

namespace s3 {

/*
 Health check controller. GET /health — авторизации не требуется.
 */
class HealthController : public drogon::HttpSimpleController<HealthController> {
public:
    void asyncHandleHttpRequest(
        const drogon::HttpRequestPtr& req,
        std::function<void(const drogon::HttpResponsePtr&)>&& callback) override;

    PATH_LIST_BEGIN
    PATH_ADD("/health", drogon::Get, "s3::CORSFilter");
    PATH_LIST_END
};

}
