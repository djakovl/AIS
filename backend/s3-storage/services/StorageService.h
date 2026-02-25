/*
 Грузчик — storage layer. Directory structure:
 {base_path}/users/{user_id}/buckets/{bucket_id}/files/{storage_key}
 */

#pragma once

#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>

namespace s3 {

class StorageException : public std::runtime_error {
public:
    explicit StorageException(const std::string& msg, int httpStatus = 500);
    int getHttpStatus() const { return httpStatus_; }

private:
    int httpStatus_;
};

class StorageService {
public:
    static StorageService& instance();

    void setBasePath(const std::string& path);
    std::string getBasePath() const { return basePath_; }

    std::string generateStorageKey();

    std::string getFullPath(const std::string& userId,
                           const std::string& bucketId,
                           const std::string& storageKey) const;

    std::string getBucketPath(const std::string& userId,
                              const std::string& bucketId) const;

    void writeFile(const std::string& fullPath, std::istream& data);
    std::ifstream readFile(const std::string& fullPath);

    void copyFile(const std::string& srcPath, const std::string& dstPath);

    bool deleteFile(const std::string& fullPath, std::string* outError = nullptr);

    bool removeDirectory(const std::string& path);

    bool ensureDirectory(const std::string& path);

    StorageService(const StorageService&) = delete;
    StorageService& operator=(const StorageService&) = delete;

private:
    StorageService() = default;
    std::string basePath_;
};

} 

