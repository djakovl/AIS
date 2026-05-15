/*
 Content-Type whitelist and extension blacklist for upload validation.
 Охранник — blocks dangerous file types (.php, .exe, .sh, etc.).
 */

#pragma once

#include <drogon/HttpTypes.h>
#include <string>

namespace s3 {

class SecurityService {
public:
    static SecurityService& instance();
    bool validateUploadFile(const std::string& fileName,
                           const std::string& contentType) const;
    bool validateUploadFile(const std::string& fileName,
                           drogon::ContentType contentType) const;

    SecurityService(const SecurityService&) = delete;
    SecurityService& operator=(const SecurityService&) = delete;

private:
    SecurityService() = default;
    static std::string getExtension(const std::string& fileName);
};

} 

