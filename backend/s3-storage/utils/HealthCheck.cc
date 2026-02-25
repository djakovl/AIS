//Implementation of async health check (DB + disk)
#include "utils/HealthCheck.h"
#include "services/DatabaseService.h"
#include "utils/Logger.h"
#include <drogon/drogon.h>
#include <fcntl.h>
#include <memory>
#include <thread>
#include <unistd.h>

namespace s3 {

namespace {

bool checkStorageWritable(const std::string& basePath) {
    if (basePath.empty()) {
        return false;
    }
    std::string probePath =
        basePath + "/.health_probe_" + std::to_string(getpid());
    int fd = open(probePath.c_str(), O_WRONLY | O_CREAT | O_TRUNC, 0600);
    if (fd < 0) {
        return false;
    }
    const char byte = 'x';
    ssize_t n = write(fd, &byte, 1);
    close(fd);
    if (n != 1) {
        unlink(probePath.c_str());
        return false;
    }
    int r = unlink(probePath.c_str());
    return (r == 0);
}

HealthResult makeOkResult() {
    Json::Value body;
    body["status"] = "ok";
    body["database"] = "connected";
    body["storage"] = "writable";
    return HealthResult{200, std::move(body)};
}

HealthResult makeDegradedResult(const std::string& databaseStatus,
                                const std::string& storageStatus) {
    Json::Value body;
    body["status"] = "degraded";
    body["database"] = databaseStatus;
    body["storage"] = storageStatus;
    return HealthResult{503, std::move(body)};
}

}  // namespace

std::string HealthCheck::getStoragePath() {
    try {
        const auto& config = drogon::app().getCustomConfig();
        if (!config.isNull() && config.isMember("storage") &&
            config["storage"].isMember("base_path")) {
            return config["storage"]["base_path"].asString();
        }
    } catch (...) {
    }
    return "/opt/storage";
}

void HealthCheck::checkAsync(Callback&& callback) {
    std::string storagePath = getStoragePath();
    auto cb = std::make_shared<Callback>(std::move(callback));
    auto* loop = drogon::app().getLoop();

    auto runDiskCheckAndRespond = [loop, cb, storagePath](
                                     bool dbOk,
                                     const std::string& dbStatus) {
        std::thread([loop, cb, dbOk, dbStatus, storagePath] {
            bool diskOk = checkStorageWritable(storagePath);
            std::string storageStatus =
                diskOk ? "writable" : "not writable";

            HealthResult result;
            if (dbOk && diskOk) {
                result = makeOkResult();
            } else {
                if (!dbOk) {
                    Logger::warn("Health check: database disconnected",
                                "", "");
                }
                if (!diskOk) {
                    Logger::warn("Health check: storage path not writable",
                                "", "");
                }
                result = makeDegradedResult(dbStatus, storageStatus);
            }

            loop->queueInLoop([cb, result = std::move(result)]() mutable {
                (*cb)(std::move(result));
            });
        }).detach();
    };

    try {
        DatabaseService::instance().execSqlAsync(
            "SELECT 1",
            [runDiskCheckAndRespond](const drogon::orm::Result&) {
                runDiskCheckAndRespond(true, "connected");
            },
            [runDiskCheckAndRespond](const drogon::orm::DrogonDbException& e) {
                (void)e;
                runDiskCheckAndRespond(false, "disconnected");
            });
    } catch (const std::exception&) {
        Logger::warn("Health check: database client unavailable", "", "");
        runDiskCheckAndRespond(false, "disconnected");
    }
}

}  // namespace s3
