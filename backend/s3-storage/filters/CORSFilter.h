/*
 * CORS filter for cross-origin requests.
 * Handles OPTIONS preflight and adds CORS headers. Uses HttpMiddleware to attach Access-Control-* headers to responses.
 */

#pragma once

#include <drogon/drogon.h>

namespace s3 {

/*
CORS support: OPTIONS preflight + headers on responses.
Allow: GET, POST, DELETE, OPTIONS. Headers: X-User-Id, X-Request-Id, Content-Type.
 */
class CORSFilter : public drogon::HttpMiddleware<CORSFilter> {
public:
    CORSFilter() = default;

    void invoke(const drogon::HttpRequestPtr& req,
                drogon::MiddlewareNextCallback&& nextCb,
                drogon::MiddlewareCallback&& mcb) override;
};

}