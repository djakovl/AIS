//Implementation of UUID v4 and token generation

#include "utils/UUIDGenerator.h"
#include <array>
#include <vector>

namespace s3 {

namespace {

std::mt19937& getRng() {
    static thread_local std::random_device rd;
    static thread_local std::mt19937 gen(rd());
    return gen;
}

} 

char UUIDGenerator::nibbleToHex(uint8_t nibble) {
    static const char hex[] = "0123456789abcdef";
    return hex[nibble & 0x0f];
}

std::string UUIDGenerator::toHex(const unsigned char* bytes, size_t count) {
    std::string result;
    result.reserve(count * 2);
    for (size_t i = 0; i < count; ++i) {
        result += nibbleToHex(bytes[i] >> 4);
        result += nibbleToHex(bytes[i]);
    }
    return result;
}

std::string UUIDGenerator::generateUUID() {
    std::uniform_int_distribution<int> dist(0, 255);
    std::array<unsigned char, 16> bytes;
    for (size_t i = 0; i < 16; ++i) {
        bytes[i] = static_cast<unsigned char>(dist(getRng()));
    }
    // UUID v4: set version (4) in byte 6, variant (10) in byte 8
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    std::string result;
    result.reserve(36);
    result += toHex(bytes.data(), 4);
    result += '-';
    result += toHex(bytes.data() + 4, 2);
    result += '-';
    result += toHex(bytes.data() + 6, 2);
    result += '-';
    result += toHex(bytes.data() + 8, 2);
    result += '-';
    result += toHex(bytes.data() + 10, 6);
    return result;
}

std::string UUIDGenerator::generateToken(size_t length) {
    size_t numBytes = (length + 1) / 2;
    std::uniform_int_distribution<int> dist(0, 255);
    std::vector<unsigned char> bytes(numBytes);
    for (size_t i = 0; i < numBytes; ++i) {
        bytes[i] = static_cast<unsigned char>(dist(getRng()));
    }
    std::string result = toHex(bytes.data(), numBytes);
    if (result.size() > length) {
        result.resize(length);
    }
    return result;
}

}  // namespace s3
