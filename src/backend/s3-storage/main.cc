/*
S3 Storage Service entry point.
Loads config.json, initializes StorageService from custom_config,
registers routes with filters, graceful shutdown on SIGTERM/SIGINT.
Ignores SIGPIPE to avoid crash when writing to closed client connections.
DbClient auto-loaded by Drogon from db_clients. client_max_body_size
from app config (100M default, configurable via config.json).
 */

#include <csignal>
#include <cstdlib>
#include <drogon/drogon.h>
#include "controllers/FilesController.h"
#include "controllers/HealthController.h"
#include "controllers/SwaggerController.h"
#include "services/CleanupService.h"
#include "services/StorageService.h"
#include "utils/Logger.h"

int main() {
    // Игнорируем SIGPIPE — запись в закрытый сокет иначе завершит процесс
    std::signal(SIGPIPE, SIG_IGN);

    drogon::app().loadConfigFile("config.json");

    // Обработка CORS preflight (OPTIONS) до фильтров — иначе GatewayAuth отклонит без X-User-Id — routes don't match OPTIONS,
    // and GatewayAuthFilter would reject it (no X-User-Id in preflight)
    drogon::app().registerPreRoutingAdvice(
        [](const drogon::HttpRequestPtr& req,
           drogon::FilterCallback&& stop,
           drogon::FilterChainCallback&& pass) {
            if (req->method() != drogon::HttpMethod::Options) {
                pass();
                return;
            }
            const std::string& path = req->path();
            if (path.compare(0, 6, "/files") != 0 && path != "/health") {
                pass();
                return;
            }
            auto resp = drogon::HttpResponse::newHttpResponse();
            resp->setStatusCode(drogon::HttpStatusCode::k204NoContent);
            resp->addHeader("Access-Control-Allow-Origin", "*");
            resp->addHeader("Access-Control-Allow-Methods",
                           "GET, POST, DELETE, OPTIONS");
            resp->addHeader("Access-Control-Allow-Headers",
                           "X-User-Id, X-Request-Id, Content-Type");
            resp->addHeader("Access-Control-Max-Age", "86400");
            std::string requestId = req->getHeader("x-request-id");
            if (!requestId.empty()) {
                resp->addHeader("X-Request-Id", requestId);
            }
            stop(resp);
        });

    auto customConfig = drogon::app().getCustomConfig();
    std::string storageBasePath = "/opt/storage";
    std::string uploadPath = "/tmp";

    if (!customConfig.empty() && customConfig.isMember("storage")) {
        if (customConfig["storage"].isMember("base_path")) {
            storageBasePath =
                customConfig["storage"]["base_path"].asString();
        }
        if (customConfig["storage"].isMember("upload_path")) {
            uploadPath =
                customConfig["storage"]["upload_path"].asString();
        } else if (!storageBasePath.empty()) {
            uploadPath = storageBasePath + "/tmp";
        }
    }

    const char* envBasePath = std::getenv("STORAGE_BASE_PATH");
    if (envBasePath && envBasePath[0] != '\0') {
        storageBasePath = envBasePath;
        uploadPath = storageBasePath + "/tmp";
    }

    drogon::app().setUploadPath(uploadPath);

    // Корень хранилища: users/{user_id}/buckets/{bucket_id}/files/
    s3::StorageService::instance().setBasePath(storageBasePath);

    // Регистрация эндпоинтов: health без авторизации, остальные через Filters
    drogon::app().registerHttpSimpleController(
        "/health", "s3::HealthController", {drogon::Get, "s3::CORSFilter"});

    drogon::app().registerController(
        std::make_shared<s3::FilesController>());

    bool swaggerEnabled = s3::SwaggerController::isSwaggerEnabled();
    if (swaggerEnabled) {
        drogon::app().registerController(
            std::make_shared<s3::SwaggerController>());
    }

    drogon::app().setTermSignalHandler([]() {
        s3::Logger::info("SIGTERM received, initiating graceful shutdown", "", "");
        drogon::app().quit();
    });
    drogon::app().setIntSignalHandler([]() {
        s3::Logger::info("SIGINT received, initiating graceful shutdown", "", "");
        drogon::app().quit();
    });

    // Фоновая очистка: hard-delete записей и файлов после 7 дней soft-delete (раз в час)
    drogon::app().getLoop()->runEvery(3600.0, []() {
        s3::CleanupService::instance().cleanupFilesWithDeletedMark();
    });

    s3::Logger::info("S3 Storage Service starting, ready to accept requests", "", "");
    drogon::app().run();
    return 0;
}
