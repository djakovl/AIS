# Unit tests (link project sources needed by tests)
add_executable(s3_unit_tests
    unit/test_uuid_generator.cc
    unit/test_response_helper.cc
    unit/test_gateway_auth_filter.cc
    ${CMAKE_SOURCE_DIR}/utils/UUIDGenerator.cc
    ${CMAKE_SOURCE_DIR}/utils/ResponseHelper.cc
    ${CMAKE_SOURCE_DIR}/filters/GatewayAuthFilter.cc
)
target_include_directories(s3_unit_tests PRIVATE ${CMAKE_SOURCE_DIR})
target_link_libraries(s3_unit_tests PRIVATE
    GTest::gtest_main
    Drogon::Drogon
)
include(GoogleTest)
gtest_discover_tests(s3_unit_tests
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
)

# Integration tests (shell scripts - require server running; skip if unreachable)
find_program(BASH_EXECUTABLE bash)
if(BASH_EXECUTABLE)
    add_test(NAME integration_health
        COMMAND ${BASH_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/integration/test_health.sh
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    add_test(NAME integration_gateway_auth
        COMMAND ${BASH_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/integration/test_gateway_auth.sh
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    add_test(NAME integration_delete_file
        COMMAND ${BASH_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/integration/test_delete_file.sh
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    add_test(NAME integration_delete_file_404
        COMMAND ${BASH_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/integration/test_delete_file_404.sh
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    add_test(NAME integration_delete_bucket
        COMMAND ${BASH_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/integration/test_delete_bucket.sh
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    add_test(NAME integration_delete_bucket_400
        COMMAND ${BASH_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/integration/test_delete_bucket_400.sh
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    add_test(NAME integration_delete_401
        COMMAND ${BASH_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/integration/test_delete_401.sh
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    add_test(NAME integration_delete_file_rest
        COMMAND ${BASH_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/integration/test_delete_file_rest.sh
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    add_test(NAME integration_delete_bucket_rest
        COMMAND ${BASH_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/integration/test_delete_bucket_rest.sh
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    add_test(NAME integration_delete_file_rest_404
        COMMAND ${BASH_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/integration/test_delete_file_rest_404.sh
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    add_test(NAME integration_delete_file_rest_400
        COMMAND ${BASH_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/integration/test_delete_file_rest_400.sh
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    add_test(NAME integration_move_cross_bucket_root
        COMMAND ${BASH_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/integration/test_move_cross_bucket_root.sh
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    add_test(NAME integration_move_cross_bucket_folder
        COMMAND ${BASH_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/integration/test_move_cross_bucket_folder.sh
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    add_test(NAME integration_move_same_bucket
        COMMAND ${BASH_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/integration/test_move_same_bucket.sh
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    add_test(NAME integration_move_folder_cross_bucket_400
        COMMAND ${BASH_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/integration/test_move_folder_cross_bucket_400.sh
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    add_test(NAME integration_move_dest_bucket_404
        COMMAND ${BASH_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/integration/test_move_dest_bucket_404.sh
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    add_test(NAME integration_move_quota_exceeded
        COMMAND ${BASH_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/integration/test_move_quota_exceeded.sh
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    add_test(NAME integration_deduplicate_bucket
        COMMAND ${BASH_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/integration/test_deduplicate_bucket.sh
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    add_test(NAME integration_shared_download
        COMMAND ${BASH_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/integration/test_shared_download.sh
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    add_test(NAME integration_shared_download_404
        COMMAND ${BASH_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/integration/test_shared_download_404.sh
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    set_tests_properties(integration_health integration_gateway_auth
        integration_delete_file integration_delete_file_404
        integration_delete_bucket integration_delete_bucket_400
        integration_delete_401
        integration_delete_file_rest integration_delete_bucket_rest
        integration_delete_file_rest_404 integration_delete_file_rest_400
        integration_move_cross_bucket_root integration_move_cross_bucket_folder
        integration_move_same_bucket integration_move_folder_cross_bucket_400
        integration_move_dest_bucket_404 integration_move_quota_exceeded
        integration_deduplicate_bucket
        integration_shared_download integration_shared_download_404
        PROPERTIES SKIP_RETURN_CODE 77)
endif()
