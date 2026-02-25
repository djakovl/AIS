/**
UUID v4 and token generation for S3 Storage Service.
Used for file ids, bucket ids, storage keys, and shared link tokens.
Cross-platform implementation using std::random.
 */

#pragma once

#include <cstdint>
#include <random>
#include <string>

namespace s3 {

//Generates UUIDs and random tokens for storage entities.

class UUIDGenerator {
public:
//Generate a UUID v4 string (e.g. "550e8400-e29b-41d4-a716-446655440000")
    static std::string generateUUID();
//Generate a random hex token for shared links.

    static std::string generateToken(size_t length = 32);

private:
    static std::string toHex(const unsigned char* bytes, size_t count);
    static char nibbleToHex(uint8_t nibble);
};

}  
