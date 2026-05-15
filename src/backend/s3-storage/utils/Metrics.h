//Optional request/error counters for S3 Storage Service.
//Логист — observability. Lightweight atomic counters for basic metrics.
//Can be used by filters or controllers to track requests and errors.

#pragma once

#include <atomic>
#include <cstdint>

namespace s3 {

class Metrics {
public:
//Get singleton instance.
    static Metrics& instance();
 //Increment total request count.
    void incrementRequests();
//Increment total error count.
    void incrementErrors();
//Get current request count.
    uint64_t getRequestCount() const;
// Get current error count.
    uint64_t getErrorCount() const;
//Reset all counters (e.g. for testing).
    void reset();
    Metrics(const Metrics&) = delete;
    Metrics& operator=(const Metrics&) = delete;

private:
    Metrics() = default;

    std::atomic<uint64_t> requests_{0};
    std::atomic<uint64_t> errors_{0};
};

}
