// Implementation of standard JSON response builders.
#include "utils/ResponseHelper.h"

namespace s3 {

namespace {

drogon::HttpStatusCode toHttpStatusCode(int code) {
    if (code < 100 || code > 599) {
        return drogon::HttpStatusCode::k500InternalServerError;
    }
    return static_cast<drogon::HttpStatusCode>(code);
}

void addRequestIdHeader(const drogon::HttpRequestPtr& req,
                        drogon::HttpResponsePtr& resp) {
    if (req) {
        std::string requestId = req->getHeader("x-request-id");
        if (!requestId.empty()) {
            resp->addHeader("X-Request-Id", requestId);
        }
    }
}

void addCorsHeaders(drogon::HttpResponsePtr& resp) {
    resp->addHeader("Access-Control-Allow-Origin", "*");
    resp->addHeader("Access-Control-Allow-Methods",
                    "GET, POST, DELETE, OPTIONS");
    resp->addHeader("Access-Control-Allow-Headers",
                    "X-User-Id, X-Request-Id, Content-Type");
    resp->addHeader("Access-Control-Max-Age", "86400");
}

} 

drogon::HttpResponsePtr ResponseHelper::buildSuccess(
    const drogon::HttpRequestPtr& req,
    Json::Value&& data,
    int statusCode) {
    Json::Value root;
    root["success"] = true;
    root["data"] = std::move(data);

    auto resp = drogon::HttpResponse::newHttpJsonResponse(root);
    resp->setStatusCode(toHttpStatusCode(statusCode));
    addRequestIdHeader(req, resp);
    addCorsHeaders(resp);
    return resp;
}

drogon::HttpResponsePtr ResponseHelper::buildError(
    const drogon::HttpRequestPtr& req,
    const std::string& code,
    const std::string& message,
    int statusCode) {
    Json::Value errorObj;
    errorObj["code"] = code;
    errorObj["message"] = message;

    Json::Value root;
    root["success"] = false;
    root["error"] = std::move(errorObj);

    auto resp = drogon::HttpResponse::newHttpJsonResponse(root);
    resp->setStatusCode(toHttpStatusCode(statusCode));
    addRequestIdHeader(req, resp);
    addCorsHeaders(resp);
    return resp;
}

} 

