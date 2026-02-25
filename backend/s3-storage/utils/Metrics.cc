//Implementation of request/error counters

#include "utils/Metrics.h"

namespace s3 {

Metrics& Metrics::instance() {
    static Metrics instance;
    return instance;
}

void Metrics::incrementRequests() {
    requests_.fetch_add(1, std::memory_order_relaxed);
}

void Metrics::incrementErrors() {
    errors_.fetch_add(1, std::memory_order_relaxed);
}

uint64_t Metrics::getRequestCount() const {
    return requests_.load(std::memory_order_relaxed);
}

uint64_t Metrics::getErrorCount() const {
    return errors_.load(std::memory_order_relaxed);
}

void Metrics::reset() {
    requests_.store(0, std::memory_order_relaxed);
    errors_.store(0, std::memory_order_relaxed);
}

}  // namespace s3
