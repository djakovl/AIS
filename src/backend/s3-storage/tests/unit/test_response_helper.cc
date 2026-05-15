
// Unit tests for ResponseHelper (buildSuccess/buildError JSON shape).
// Naming: TestName_Component_ExpectedBehavior


#include "utils/ResponseHelper.h"
#include <drogon/drogon.h>
#include <gtest/gtest.h>
#include <json/json.h>

namespace s3 {
namespace {

drogon::HttpRequestPtr makeEmptyRequest() {
    return drogon::HttpRequest::newHttpRequest();
}

void parseJsonBody(const drogon::HttpResponsePtr& resp, Json::Value& out) {
    ASSERT_NE(resp, nullptr);
    std::string body = resp->getBody();
    Json::CharReaderBuilder builder;
    std::unique_ptr<Json::CharReader> reader(builder.newCharReader());
    std::string errs;
    ASSERT_TRUE(reader->parse(body.data(), body.data() + body.size(), &out, &errs))
        << "Invalid JSON: " << errs;
}

}  // namespace

TEST(ResponseHelper_BuildSuccess_JsonShape, Component_ExpectedBehavior) {
    // Arrange
    auto req = makeEmptyRequest();
    Json::Value data;
    data["id"] = "test-id";
    data["name"] = "test";

    // Act
    auto resp = ResponseHelper::buildSuccess(req, std::move(data), 200);

    // Assert
    ASSERT_NE(resp, nullptr);
    ASSERT_EQ(resp->getStatusCode(), drogon::HttpStatusCode::k200OK);

    Json::Value root;
    parseJsonBody(resp, root);
    ASSERT_TRUE(root.isMember("success"));
    ASSERT_TRUE(root["success"].asBool());
    ASSERT_TRUE(root.isMember("data"));
    ASSERT_EQ(root["data"]["id"].asString(), "test-id");
    ASSERT_EQ(root["data"]["name"].asString(), "test");
}

TEST(ResponseHelper_BuildSuccess_StatusCode201, Component_ExpectedBehavior) {
    // Arrange
    auto req = makeEmptyRequest();
    Json::Value data;
    data["created"] = true;

    // Act
    auto resp = ResponseHelper::buildSuccess(req, std::move(data), 201);

    // Assert
    ASSERT_NE(resp, nullptr);
    ASSERT_EQ(resp->getStatusCode(), drogon::HttpStatusCode::k201Created);

    Json::Value root;
    parseJsonBody(resp, root);
    ASSERT_TRUE(root["success"].asBool());
    ASSERT_TRUE(root.isMember("data"));
}

TEST(ResponseHelper_BuildError_JsonShape, Component_ExpectedBehavior) {
    // Arrange
    auto req = makeEmptyRequest();
    std::string code = "UNAUTHORIZED";
    std::string message = "Missing or invalid X-User-Id";

    // Act
    auto resp = ResponseHelper::buildError(req, code, message, 401);

    // Assert
    ASSERT_NE(resp, nullptr);
    ASSERT_EQ(resp->getStatusCode(), drogon::HttpStatusCode::k401Unauthorized);

    Json::Value root;
    parseJsonBody(resp, root);
    ASSERT_TRUE(root.isMember("success"));
    ASSERT_FALSE(root["success"].asBool());
    ASSERT_TRUE(root.isMember("error"));
    ASSERT_EQ(root["error"]["code"].asString(), code);
    ASSERT_EQ(root["error"]["message"].asString(), message);
}

TEST(ResponseHelper_BuildError_StatusCode404, Component_ExpectedBehavior) {
    // Arrange
    auto req = makeEmptyRequest();

    // Act
    auto resp =
        ResponseHelper::buildError(req, "NOT_FOUND", "Resource not found", 404);

    // Assert
    ASSERT_NE(resp, nullptr);
    ASSERT_EQ(resp->getStatusCode(), drogon::HttpStatusCode::k404NotFound);

    Json::Value root;
    parseJsonBody(resp, root);
    ASSERT_FALSE(root["success"].asBool());
    ASSERT_EQ(root["error"]["code"].asString(), "NOT_FOUND");
}

TEST(ResponseHelper_BuildSuccess_EchoesXRequestId, Component_ExpectedBehavior) {
    // Arrange
    auto req = makeEmptyRequest();
    req->addHeader("X-Request-Id", "req-12345");
    Json::Value data;

    // Act
    auto resp = ResponseHelper::buildSuccess(req, std::move(data), 200);

    // Assert
    ASSERT_NE(resp, nullptr);
    std::string echoed = resp->getHeader("X-Request-Id");
    ASSERT_EQ(echoed, "req-12345");
}

}  // namespace s3
