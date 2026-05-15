/*
 Rate limiting filter per user (X-User-Id) or IP.
 In-memory sliding window. Returns 429 when limit exceeded.
Default: 100 requests per minute (configurable).
 */
#pragma once

#include <drogon/drogon.h>
#include <chrono>
#include <mutex>
#include <string>
#include <unordered_map>

namespace s3 {

/*
 Limits requests per user (X-User-Id) or IP when X-User-Id absent.
Thread-safe in-memory implementation.
 */

class RateLimitFilter : public drogon::HttpFilter<RateLimitFilter> {
public:
    void doFilter(const drogon::HttpRequestPtr& req,
                  drogon::FilterCallback&& fcb,
                  drogon::FilterChainCallback&& fccb) override;

private:
    struct Window {
        int count = 0;
        std::chrono::steady_clock::time_point windowStart{};
    };

    static constexpr int kDefaultLimit = 100;
    static constexpr int kWindowSec = 60;

    mutable std::mutex mutex_;
    std::unordered_map<std::string, Window> windows_;
};

} 
