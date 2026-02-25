/*
  Валидация загрузок: whitelist Content-Type, blacklist расширений (.php, .exe и т.д.)
  Блокирует опасные типы файлов до записи на диск.
 */

#include "services/SecurityService.h"
#include <drogon/HttpTypes.h>
#include <algorithm>
#include <cctype>
#include <string>
#include <unordered_set>

namespace s3 {

namespace {

// Заблокированные расширения — выполнение на сервере
const std::unordered_set<std::string> kBlockedExtensions{
    "php", "phtml", "phar", "sh", "bash", "exe", "bat", "cmd", "ps1", "com"};

// Whitelist MIME types; also allow application/octet-stream for binary
const std::unordered_set<std::string> kAllowedMimeTypes{
    "image/jpeg",       "image/png",    "image/gif",    "image/webp",
    "image/svg+xml",     "application/pdf",
    "text/plain",       "text/csv",     "text/html",
    "application/zip", "application/x-zip-compressed",
    "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "application/json", "application/octet-stream"};

bool startsWith(const std::string& s, const std::string& prefix) {
    return s.size() >= prefix.size() &&
           s.compare(0, prefix.size(), prefix) == 0;
}

std::string toLower(std::string s) {
    std::transform(s.begin(), s.end(), s.begin(),
                  [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    return s;
}

}  // namespace

SecurityService& SecurityService::instance() {
    static SecurityService instance;
    return instance;
}

std::string SecurityService::getExtension(const std::string& fileName) {
    size_t dot = fileName.rfind('.');
    if (dot == std::string::npos || dot == fileName.size() - 1) {
        return "";
    }
    return toLower(fileName.substr(dot + 1));
}

bool SecurityService::validateUploadFile(const std::string& fileName,
                                         const std::string& contentType) const {
    std::string ext = getExtension(fileName);
    if (kBlockedExtensions.count(ext) > 0) {
        return false;
    }

    // Parse Content-Type: may have "image/png; charset=utf-8"
    std::string mime = contentType;
    size_t semicolon = mime.find(';');
    if (semicolon != std::string::npos) {
        mime = mime.substr(0, semicolon);
    }
    // Trim whitespace
    while (!mime.empty() && std::isspace(static_cast<unsigned char>(mime.back()))) {
        mime.pop_back();
    }
    mime = toLower(mime);

    if (mime.empty()) {
        mime = "application/octet-stream";
    }

    if (kAllowedMimeTypes.count(mime) > 0) {
        return true;
    }
    // Wildcard: image/*, text/* (limited)
    if (startsWith(mime, "image/") || startsWith(mime, "text/")) {
        return true;
    }
    if (startsWith(mime, "application/vnd.openxmlformats-officedocument.")) {
        return true;
    }

    return false;
}

bool SecurityService::validateUploadFile(const std::string& fileName,
                                        drogon::ContentType contentType) const {
    std::string ext = getExtension(fileName);
    if (kBlockedExtensions.count(ext) > 0) {
        return false;
    }
    switch (contentType) {
        case drogon::CT_APPLICATION_X_HTTPD_PHP:
            return false;
        case drogon::CT_APPLICATION_OCTET_STREAM:
        case drogon::CT_APPLICATION_JSON:
        case drogon::CT_APPLICATION_PDF:
        case drogon::CT_APPLICATION_ZIP:
        case drogon::CT_APPLICATION_MSWORD:
        case drogon::CT_APPLICATION_MSWORDX:
        case drogon::CT_TEXT_PLAIN:
        case drogon::CT_TEXT_HTML:
        case drogon::CT_TEXT_CSV:
        case drogon::CT_IMAGE_JPG:
        case drogon::CT_IMAGE_PNG:
        case drogon::CT_IMAGE_GIF:
        case drogon::CT_IMAGE_WEBP:
        case drogon::CT_IMAGE_SVG_XML:
        case drogon::CT_IMAGE_AVIF:
        case drogon::CT_IMAGE_APNG:
        case drogon::CT_IMAGE_BMP:
        case drogon::CT_IMAGE_TIFF:
        case drogon::CT_NONE:
        case drogon::CT_CUSTOM:
            return true;
        default:
            return true;  // Allow known Drogon types
    }
}

} 

