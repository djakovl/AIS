
#include "controllers/HealthController.h"
#include "utils/HealthCheck.h"
#include <json/json.h>

namespace s3 {

namespace {

void addRequestIdHeader(const drogon::HttpRequestPtr& req,
                        drogon::HttpResponsePtr& resp) {
    if (req) {
        std::string requestId = req->getHeader("x-request-id");
        if (!requestId.empty()) {
            resp->addHeader("X-Request-Id", requestId);
        }
    }
}

}

void HealthController::asyncHandleHttpRequest(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) {
    HealthCheck::checkAsync([req, callback = std::move(callback)](
                                HealthResult result) mutable {
        auto resp =
            drogon::HttpResponse::newHttpJsonResponse(std::move(result.body));
        resp->setStatusCode(
            static_cast<drogon::HttpStatusCode>(result.statusCode));
        addRequestIdHeader(req, resp);
        callback(resp);
    });
}

} 
