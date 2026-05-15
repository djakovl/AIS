#include "filters/CORSFilter.h"
#include <string>

namespace s3 {

namespace {

constexpr const char* kAllowOrigin = "*";
constexpr const char* kAllowMethods = "GET, POST, DELETE, OPTIONS";
constexpr const char* kAllowHeaders =
    "X-User-Id, X-Request-Id, Content-Type";

void addCorsHeaders(const drogon::HttpResponsePtr& resp) {
    resp->addHeader("Access-Control-Allow-Origin", kAllowOrigin);
    resp->addHeader("Access-Control-Allow-Methods", kAllowMethods);
    resp->addHeader("Access-Control-Allow-Headers", kAllowHeaders);
    resp->addHeader("Access-Control-Max-Age", "86400");
}

} 

void CORSFilter::invoke(const drogon::HttpRequestPtr& req,
                       drogon::MiddlewareNextCallback&& nextCb,
                       drogon::MiddlewareCallback&& mcb) {
    if (req->method() == drogon::HttpMethod::Options) {
        auto resp = drogon::HttpResponse::newHttpResponse();
        resp->setStatusCode(drogon::HttpStatusCode::k204NoContent);
        addCorsHeaders(resp);
        std::string requestId = req->getHeader("x-request-id");
        if (!requestId.empty()) {
            resp->addHeader("X-Request-Id", requestId);
        }
        mcb(resp);
        return;
    }

    nextCb([mcb = std::move(mcb)](const drogon::HttpResponsePtr& resp) {
        if (resp) {
            addCorsHeaders(resp);
        }
        mcb(resp);
    });
}

}
