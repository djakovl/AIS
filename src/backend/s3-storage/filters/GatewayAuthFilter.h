/**
 * @file GatewayAuthFilter.h
 * @brief Filter requiring X-User-Id header from API Gateway.
 *
 * Trusts Gateway headers. Returns 401 when X-User-Id is missing or invalid
 * (UUID format). Does NOT validate Redis sessions or CSRF.
 */

#pragma once

#include <drogon/drogon.h>

namespace s3 {

/**
 * @brief Requires X-User-Id header, validates UUID format.
 * Apply to /files/* routes.
 */
class GatewayAuthFilter : public drogon::HttpFilter<GatewayAuthFilter> {
public:
    void doFilter(const drogon::HttpRequestPtr& req,
                  drogon::FilterCallback&& fcb,
                  drogon::FilterChainCallback&& fccb) override;
};

}  // namespace s3
