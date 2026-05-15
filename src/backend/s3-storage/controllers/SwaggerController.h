
#pragma once
#include <drogon/drogon.h>

namespace s3 {

class SwaggerController : public drogon::HttpController<SwaggerController, false> {
public:
    void getSpec(const drogon::HttpRequestPtr& req,
                 std::function<void(const drogon::HttpResponsePtr&)>&& callback);
    void getUi(const drogon::HttpRequestPtr& req,
               std::function<void(const drogon::HttpResponsePtr&)>&& callback);

    METHOD_LIST_BEGIN
    ADD_METHOD_TO(SwaggerController::getSpec, "/swagger.json", drogon::Get);
    ADD_METHOD_TO(SwaggerController::getUi, "/swagger", drogon::Get);
    METHOD_LIST_END

    static bool isSwaggerEnabled();
};

} 
