#include "filters/RateLimitFilter.h"
#include "utils/ResponseHelper.h"
#include <chrono>

namespace s3 {

void RateLimitFilter::doFilter(const drogon::HttpRequestPtr& req,
                               drogon::FilterCallback&& fcb,
                               drogon::FilterChainCallback&& fccb) {
    std::string key = req->getHeader("X-User-Id");
    if (key.empty()) {
        key = req->getPeerAddr().toIpPort();
    }

    auto now = std::chrono::steady_clock::now();
    auto windowEnd = now - std::chrono::seconds(kWindowSec);

    std::lock_guard<std::mutex> lock(mutex_);
    auto& w = windows_[key];

    if (w.count == 0 || w.windowStart < windowEnd) {
        w.windowStart = now;
        w.count = 1;
    } else {
        ++w.count;
        if (w.count > kDefaultLimit) {
            auto resp = ResponseHelper::buildError(
                req, "TOO_MANY_REQUESTS",
                "Rate limit exceeded. Try again later.", 429);
            fcb(resp);
            return;
        }
    }

    fccb();
}

} 
