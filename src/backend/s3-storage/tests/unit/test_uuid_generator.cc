/*
test_uuid_generator.cc
 // Unit tests for UUIDGenerator (format, token length).
 // Naming: TestName_Component_ExpectedBehavior
 */

#include "utils/UUIDGenerator.h"
#include <algorithm>
#include <gtest/gtest.h>
#include <regex>

namespace s3 {
namespace {

const std::regex kUuidV4Regex{
    R"(^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$)"};

bool matchesUuidFormat(const std::string& s) {
    return std::regex_match(s, kUuidV4Regex);
}

}  // namespace

TEST(UUIDGenerator_GenerateUUID_ReturnsValidFormat, Component_ExpectedBehavior) {
    // Arrange
    const int iterations = 100;

    // Act & Assert
    for (int i = 0; i < iterations; ++i) {
        std::string uuid = UUIDGenerator::generateUUID();
        ASSERT_EQ(uuid.size(), 36u) << "UUID length must be 36";
        ASSERT_TRUE(matchesUuidFormat(uuid))
            << "UUID must match xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx format: "
            << uuid;
    }
}

TEST(UUIDGenerator_GenerateUUID_VersionAndVariantBits, Component_ExpectedBehavior) {
    // Arrange & Act
    std::string uuid = UUIDGenerator::generateUUID();

    // Assert: byte 14 (6th in 3rd group) should be 4 for version
    char versionChar = uuid[14];
    ASSERT_TRUE(versionChar == '4' || versionChar == '5' || versionChar == '6' ||
                versionChar == '7')
        << "Version nibble must be 4-7 for UUID v4";

    // byte 19 (1st in 4th group) should be 8/a/b for variant
    char variantChar = uuid[19];
    ASSERT_TRUE(variantChar == '8' || variantChar == '9' ||
                variantChar == 'a' || variantChar == 'b')
        << "Variant nibble must be 8/9/a/b";
}

TEST(UUIDGenerator_GenerateToken_DefaultLength, Component_ExpectedBehavior) {
    // Arrange
    const size_t defaultLen = 32;

    // Act
    std::string token = UUIDGenerator::generateToken(defaultLen);

    // Assert
    ASSERT_EQ(token.size(), defaultLen) << "Token length must equal requested";
    ASSERT_TRUE(std::all_of(token.begin(), token.end(),
                           [](char c) {
                               return (c >= '0' && c <= '9') ||
                                      (c >= 'a' && c <= 'f');
                           }))
        << "Token must be lowercase hex";
}

TEST(UUIDGenerator_GenerateToken_CustomLengths, Component_ExpectedBehavior) {
    // Arrange
    std::vector<size_t> lengths = {1, 8, 16, 64, 128};

    // Act & Assert
    for (size_t len : lengths) {
        std::string token = UUIDGenerator::generateToken(len);
        ASSERT_EQ(token.size(), len) << "Token length " << len << " mismatch";
    }
}

TEST(UUIDGenerator_GenerateToken_OddLength, Component_ExpectedBehavior) {
    // Arrange
    const size_t oddLen = 33;

    // Act
    std::string token = UUIDGenerator::generateToken(oddLen);

    // Assert
    ASSERT_EQ(token.size(), oddLen);
}

}  // namespace s3
