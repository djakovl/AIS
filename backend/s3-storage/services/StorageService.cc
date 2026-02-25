// Implementation of StorageService — file system operations
#include "services/StorageService.h"
#include "utils/UUIDGenerator.h"
#include <cerrno>
#include <filesystem>
#include <fstream>

namespace fs = std::filesystem;

namespace s3 {

StorageException::StorageException(const std::string& msg, int httpStatus)
    : std::runtime_error(msg), httpStatus_(httpStatus) {}

StorageService& StorageService::instance() {
    static StorageService instance;
    return instance;
}

void StorageService::setBasePath(const std::string& path) {
    basePath_ = path;
    if (!basePath_.empty() && basePath_.back() == '/') {
        basePath_.pop_back();
    }
}

// Генерация ключа хранения: aa/bb/uuid — шардирование для распределения нагрузки
std::string StorageService::generateStorageKey() {
    std::string uuid = UUIDGenerator::generateUUID();
    if (uuid.size() < 4) {
        return uuid;
    }
    std::string aa = uuid.substr(0, 2);
    std::string bb = uuid.substr(2, 2);
    return aa + "/" + bb + "/" + uuid;
}

std::string StorageService::getFullPath(const std::string& userId,
                                        const std::string& bucketId,
                                        const std::string& storageKey) const {
    return basePath_ + "/users/" + userId + "/buckets/" + bucketId +
           "/files/" + storageKey;
}

std::string StorageService::getBucketPath(const std::string& userId,
                                          const std::string& bucketId) const {
    return basePath_ + "/users/" + userId + "/buckets/" + bucketId + "/";
}

void StorageService::writeFile(const std::string& fullPath, std::istream& data) {
    fs::path p(fullPath);
    std::error_code ec;
    fs::create_directories(p.parent_path(), ec);
    if (ec) {
        throw StorageException("Failed to create directory: " + ec.message(),
                              500);
    }
    std::ofstream out(fullPath, std::ios::binary);
    if (!out) {
        if (errno == ENOSPC) {
            throw StorageException("Disk full", 507);
        }
        throw StorageException("Failed to open file for writing", 500);
    }
    const size_t bufSize = 65536;
    char buf[bufSize];
    while (data.read(buf, bufSize) || data.gcount() > 0) {
        out.write(buf, static_cast<std::streamsize>(data.gcount()));
        if (!out) {
            if (errno == ENOSPC) {
                out.close();
                fs::remove(fullPath, ec);
                throw StorageException("Disk full", 507);
            }
            throw StorageException("Write failed", 500);
        }
    }
}

std::ifstream StorageService::readFile(const std::string& fullPath) {
    std::ifstream in(fullPath, std::ios::binary);
    if (!in) {
        throw StorageException("File not found: " + fullPath, 404);
    }
    return in;
}

void StorageService::copyFile(const std::string& srcPath,
                             const std::string& dstPath) {
    std::ifstream in(srcPath, std::ios::binary);
    if (!in) {
        throw StorageException("File not found: " + srcPath, 404);
    }
    fs::path p(dstPath);
    std::error_code ec;
    fs::create_directories(p.parent_path(), ec);
    if (ec) {
        throw StorageException("Failed to create directory: " + ec.message(),
                              500);
    }
    std::ofstream out(dstPath, std::ios::binary);
    if (!out) {
        if (errno == ENOSPC) {
            throw StorageException("Disk full", 507);
        }
        throw StorageException("Failed to open file for writing", 500);
    }
    const size_t bufSize = 65536;
    char buf[bufSize];
    while (in.read(buf, bufSize) || in.gcount() > 0) {
        out.write(buf, static_cast<std::streamsize>(in.gcount()));
        if (!out) {
            const int savedErrno = errno;
            out.close();
            fs::remove(dstPath, ec);
            if (savedErrno == ENOSPC) {
                throw StorageException("Disk full", 507);
            }
            throw StorageException("Write failed", 500);
        }
    }
}

bool StorageService::deleteFile(const std::string& fullPath,
                                std::string* outError) {
    std::error_code ec;
    bool removed = fs::remove(fullPath, ec);
    if (!removed || ec) {
        if (outError) {
            *outError = ec ? ec.message() : "file not found";
        }
        return false;
    }
    return true;
}

bool StorageService::removeDirectory(const std::string& path) {
    std::error_code ec;
    fs::remove_all(path, ec);
    return !ec;
}

bool StorageService::ensureDirectory(const std::string& path) {
    std::error_code ec;
    fs::create_directories(path, ec);
    return !ec;
}

}  // namespace s3
