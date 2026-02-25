#include <gtest/gtest.h>
#include <drogon/HttpResponse.h>
#include <json/json.h>
#include "../../utils/ResponseHelper.h"

using namespace drogon;
using namespace s3;

namespace {

void parseJsonBody(const HttpResponsePtr& resp, Json::Value& json) {
    Json::CharReaderBuilder builder;
    std::string errs;
    std::string body(resp->getBody());
    std::istringstream stream(body);
    if (!Json::parseFromStream(builder, stream, &json, &errs)) {
        FAIL() << "Failed to parse JSON: " << errs;
    }
}

}

TEST(ResponseHelperTest, SuccessResponse) {
    auto resp = ResponseHelper::success("Operation successful");
    EXPECT_EQ(resp->getStatusCode(), k200OK);
    
    Json::Value json;
    parseJsonBody(resp, json);
    EXPECT_TRUE(json["success"].asBool());
    EXPECT_EQ(json["message"].asString(), "Operation successful");
}

TEST(ResponseHelperTest, ErrorResponse) {
    auto resp = ResponseHelper::error("Something went wrong", k500InternalServerError);
    EXPECT_EQ(resp->getStatusCode(), k500InternalServerError);
    
    Json::Value json;
    parseJsonBody(resp, json);
    EXPECT_FALSE(json["success"].asBool());
    EXPECT_EQ(json["error"].asString(), "Something went wrong");
}

TEST(ResponseHelperTest, DataResponse) {
    Json::Value data;
    data["key"] = "value";
    data["count"] = 42;
    
    auto resp = ResponseHelper::data(data);
    EXPECT_EQ(resp->getStatusCode(), k200OK);
    
    Json::Value json;
    parseJsonBody(resp, json);
    EXPECT_TRUE(json["success"].asBool());
    EXPECT_EQ(json["data"]["key"].asString(), "value");
    EXPECT_EQ(json["data"]["count"].asInt(), 42);
}

TEST(ResponseHelperTest, ValidationErrorResponse) {
    auto resp = ResponseHelper::validationError("Invalid input");
    EXPECT_EQ(resp->getStatusCode(), k400BadRequest);
    
    Json::Value json;
    parseJsonBody(resp, json);
    EXPECT_FALSE(json["success"].asBool());
    EXPECT_EQ(json["error"].asString(), "Invalid input");
}

TEST(ResponseHelperTest, NotFoundResponse) {
    auto resp = ResponseHelper::notFound("Resource not found");
    EXPECT_EQ(resp->getStatusCode(), k404NotFound);
    
    Json::Value json;
    parseJsonBody(resp, json);
    EXPECT_FALSE(json["success"].asBool());
    EXPECT_EQ(json["error"].asString(), "Resource not found");
}
