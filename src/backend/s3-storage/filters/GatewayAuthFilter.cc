#include "filters/GatewayAuthFilter.h"
#include "utils/ResponseHelper.h"
#include <regex>

namespace s3 {

namespace {

const std::regex kUuidRegex{
    R"(^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$)"};

bool isValidUuid(const std::string& s) {
    return !s.empty() && std::regex_match(s, kUuidRegex);
}

}  // namespace

// Проверка X-User-Id (UUID). Отсутствие или неверный формат → 401. S3 доверяет Gateway.
void GatewayAuthFilter::doFilter(const drogon::HttpRequestPtr& req,
                                drogon::FilterCallback&& fcb,
                                drogon::FilterChainCallback&& fccb) {
    std::string userId = req->getHeader("X-User-Id");

    if (userId.empty() || !isValidUuid(userId)) {
        auto resp = ResponseHelper::buildError(req, "UNAUTHORIZED",
                                              "Missing or invalid X-User-Id",
                                              401);
        fcb(resp);
        return;
    }

    fccb();
}

}  // namespace s3
