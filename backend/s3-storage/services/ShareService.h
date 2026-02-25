/*
 Shared link creation for POST /files/share/create.
 Секретарь — share operations. Generates unique token, validates ownership, inserts into shared_links. Token used for public download URL.
 */

#pragma once

#include <drogon/orm/Exception.h>
#include <functional>
#include <optional>
#include <string>

namespace s3 {

struct SharedLinkFileInfo {
    std::string id;           // shared_links.id
    std::string fileId;
    std::string userId;
    std::string bucketId;
    std::string storageKey;
    std::string name;
    std::string mimeType;
};


struct ShareLinkResult {
    std::string id;
    std::string token;
    std::string expiresAt;
    int maxDownloads = 0;  // 0 = unlimited
    std::string createdAt;
};


class ShareService {
public:
    static ShareService& instance();
    void createSharedLink(
        const std::string& fileId,
        const std::string& userId,
        std::optional<std::string> expiresAt,
        std::optional<int> maxDownloads,
        std::function<void(const ShareLinkResult&)> successCb,
        std::function<void(const drogon::orm::DrogonDbException&)> exceptCb);
    void getSharedLinkForDownload(
        const std::string& token,
        std::function<void(const SharedLinkFileInfo&)> successCb,
        std::function<void(const std::string& code,
                           const std::string& message,
                           int statusCode)> errorCb);
    void incrementSharedDownloadCounts(
        const std::string& sharedLinkId,
        const std::string& fileId,
        std::function<void()> doneCb,
        std::function<void(const std::string& code,
                           const std::string& message,
                           int statusCode)> errorCb);

    ShareService(const ShareService&) = delete;
    ShareService& operator=(const ShareService&) = delete;

private:
    ShareService() = default;
};

} 
