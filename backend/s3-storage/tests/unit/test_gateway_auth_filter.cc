// Unit tests for GatewayAuthFilter (missing X-User-Id returns 401).
//Naming: TestName_Component_ExpectedBehavior


#include "filters/GatewayAuthFilter.h"
#include <drogon/drogon.h>
#include <gtest/gtest.h>
#include <json/json.h>

namespace s3 {
namespace {

void parseJsonBody(const drogon::HttpResponsePtr& resp, Json::Value& out) {
    ASSERT_NE(resp, nullptr);
    std::string body = resp->getBody();
    Json::CharReaderBuilder builder;
    std::unique_ptr<Json::CharReader> reader(builder.newCharReader());
    std::string errs;
    ASSERT_TRUE(reader->parse(body.data(), body.data() + body.size(), &out, &errs))
        << "Invalid JSON: " << errs;
}

} 

TEST(GatewayAuthFilter_MissingXUserId_Returns401, Component_ExpectedBehavior) {
    // Arrange
    s3::GatewayAuthFilter filter;
    auto req = drogon::HttpRequest::newHttpRequest();
    req->setPath("/files/buckets/create");
    req->setMethod(drogon::Post);
    drogon::HttpResponsePtr capturedResp;

    drogon::FilterCallback fcb = [&capturedResp](const drogon::HttpResponsePtr& r) {
        capturedResp = r;
    };
    drogon::FilterChainCallback fccb = []() {
        FAIL() << "Filter should not call fccb when X-User-Id is missing";
    };

    // Act
    filter.doFilter(req, std::move(fcb), std::move(fccb));

    // Assert
    ASSERT_NE(capturedResp, nullptr);
    ASSERT_EQ(capturedResp->getStatusCode(), drogon::HttpStatusCode::k401Unauthorized);

    Json::Value root;
    parseJsonBody(capturedResp, root);
    ASSERT_FALSE(root["success"].asBool());
    ASSERT_EQ(root["error"]["code"].asString(), "UNAUTHORIZED");
    ASSERT_EQ(root["error"]["message"].asString(), "Missing or invalid X-User-Id");
}

TEST(GatewayAuthFilter_InvalidUuidFormat_Returns401, Component_ExpectedBehavior) {
    // Arrange
    s3::GatewayAuthFilter filter;
    auto req = drogon::HttpRequest::newHttpRequest();
    req->addHeader("X-User-Id", "not-a-valid-uuid");
    req->setPath("/files/buckets/list");
    req->setMethod(drogon::Get);
    drogon::HttpResponsePtr capturedResp;

    drogon::FilterCallback fcb = [&capturedResp](const drogon::HttpResponsePtr& r) {
        capturedResp = r;
    };
    drogon::FilterChainCallback fccb = []() {
        FAIL() << "Filter should not call fccb when X-User-Id is invalid";
    };

    // Act
    filter.doFilter(req, std::move(fcb), std::move(fccb));

    // Assert
    ASSERT_NE(capturedResp, nullptr);
    ASSERT_EQ(capturedResp->getStatusCode(), drogon::HttpStatusCode::k401Unauthorized);
    ASSERT_NE(capturedResp->getBody().find("\"UNAUTHORIZED\""), std::string::npos);
}

TEST(GatewayAuthFilter_ValidXUserId_CallsNextFilter, Component_ExpectedBehavior) {
    // Arrange
    s3::GatewayAuthFilter filter;
    auto req = drogon::HttpRequest::newHttpRequest();
    req->addHeader("X-User-Id", "550e8400-e29b-41d4-a716-446655440000");
    req->setPath("/files/buckets/list");
    req->setMethod(drogon::Get);
    bool fccbCalled = false;

    drogon::FilterCallback fcb = [](const drogon::HttpResponsePtr&) {
        FAIL() << "Filter should call fccb, not fcb, when X-User-Id is valid";
    };
    drogon::FilterChainCallback fccb = [&fccbCalled]() { fccbCalled = true; };

    // Act
    filter.doFilter(req, std::move(fcb), std::move(fccb));

    // Assert
    ASSERT_TRUE(fccbCalled) << "Filter must call chain callback for valid X-User-Id";
}

}  // namespace s3
