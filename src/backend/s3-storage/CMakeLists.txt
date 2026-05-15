cmake_minimum_required(VERSION 3.14)
project(s3-storage-service CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Drogon REQUIRED)
find_package(PostgreSQL QUIET)

option(BUILD_TESTS "Build unit and integration tests" ON)

if(BUILD_TESTS)
    include(FetchContent)
    FetchContent_Declare(
        googletest
        GIT_REPOSITORY https://github.com/google/googletest.git
        GIT_TAG v1.14.0
    )
    set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
    FetchContent_MakeAvailable(googletest)
    enable_testing()
    add_subdirectory(tests)
endif()

add_executable(s3-storage-service
    main.cc
    controllers/FilesController.cc
    controllers/HealthController.cc
    controllers/SwaggerController.cc
    filters/GatewayAuthFilter.cc
    filters/CORSFilter.cc
    filters/RateLimitFilter.cc
    services/BucketService.cc
    services/FileService.cc
    services/DatabaseService.cc
    services/SecurityService.cc
    services/ShareService.cc
    services/StorageService.cc
    services/DedupService.cc
    services/CleanupService.cc
    utils/HealthCheck.cc
    utils/Logger.cc
    utils/Metrics.cc
    utils/ResponseHelper.cc
    utils/UUIDGenerator.cc
)
target_include_directories(s3-storage-service PRIVATE ${CMAKE_SOURCE_DIR})
target_link_libraries(s3-storage-service PRIVATE Drogon::Drogon)
