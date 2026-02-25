/*
File and folder operations: create folder, list, move.
Секретарь — file/folder business logic for POST /files/folders/create,
GET /files/list, POST /files/move.
 */

#pragma once

#include "models/File.h"
#include <drogon/orm/Exception.h>
#include <functional>
#include <optional>
#include <string>
#include <vector>

namespace s3 {

class FileService {
public:
    static FileService& instance();

    void createFolder(
        const std::string& bucketId,
        const std::string& userId,
        const std::string& parentFolderId,
        const std::string& name,
        std::function<void(const File&)> successCb,
        std::function<void(const drogon::orm::DrogonDbException&)> exceptCb);

    void listFiles(
        const std::string& bucketId,
        const std::string& userId,
        const std::string& parentFolderId,
        std::function<void(const std::vector<File>&)> successCb,
        std::function<void(const drogon::orm::DrogonDbException&)> exceptCb);
    void moveFile(
        const std::string& fileId,
        const std::string& userId,
        const std::string& newParentFolderId,
        std::function<void(const File&)> successCb,
        std::function<void(const drogon::orm::DrogonDbException&)> exceptCb,
        std::optional<std::string> newBucketId = std::nullopt,
        const std::string& requestId = {});

    void deleteFile(
        const std::string& fileId,
        const std::string& userId,
        std::function<void(const File&)> successCb,
        std::function<void(const drogon::orm::DrogonDbException&)> exceptCb,
        const std::string& requestId = {});

    FileService(const FileService&) = delete;
    FileService& operator=(const FileService&) = delete;

private:
    FileService() = default;
};

}  

