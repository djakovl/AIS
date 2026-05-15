/*
PostgreSQL connection pool and database access for S3 Storage Service.
Архивариус — central DB layer. Uses Drogon DbClient from config.json db_clients.
All SELECT on buckets/files must include WHERE deleted_at IS NULL (soft delete).
 */

#pragma once

#include <drogon/orm/DbClient.h>
#include <functional>
#include <memory>
#include <string>

namespace s3 {

/*
Soft-delete filter for buckets and files tables.
Include in SELECT queries: "AND " SOFT_DELETE_CLAUSE
Or append to WHERE: "WHERE " SOFT_DELETE_CLAUSE " AND ..."
 */
inline constexpr const char* const SOFT_DELETE_CLAUSE = "deleted_at IS NULL";

/*
 PostgreSQL connection pool and query execution service.
 Configured via config.json db_clients section. Uses drogon::app().getDbClient("default").
 Credentials from env: DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD (via config template).
 */
class DatabaseService {
public:
    // Get singleton instance.
    static DatabaseService& instance();

    drogon::orm::DbClientPtr getClient(const std::string& name = "default");
    template <typename... Arguments>
    drogon::orm::Result execSqlSync(const std::string& sql, Arguments&&... args);

    template <typename Function1, typename Function2, typename... Arguments>
    void execSqlAsync(const std::string& sql,
                     Function1&& rCallback,
                     Function2&& exceptCallback,
                     Arguments&&... args);

    std::shared_ptr<drogon::orm::Transaction> newTransaction(
        const std::function<void(bool)>& commitCallback = {});

    void newTransactionAsync(
        const std::function<void(const std::shared_ptr<drogon::orm::Transaction>&)>&
            callback);

    DatabaseService(const DatabaseService&) = delete;
    DatabaseService& operator=(const DatabaseService&) = delete;

private:
    DatabaseService() = default;
};

// Template implementations

template <typename... Arguments>
drogon::orm::Result DatabaseService::execSqlSync(const std::string& sql,
                                                 Arguments&&... args) {
    auto client = getClient();  // throws if unavailable
    return client->execSqlSync(sql, std::forward<Arguments>(args)...);
}

template <typename Function1, typename Function2, typename... Arguments>
void DatabaseService::execSqlAsync(const std::string& sql,
                                   Function1&& rCallback,
                                   Function2&& exceptCallback,
                                   Arguments&&... args) {
    auto client = getClient();  // throws if unavailable
    client->execSqlAsync(sql,
                        std::forward<Function1>(rCallback),
                        std::forward<Function2>(exceptCallback),
                        std::forward<Arguments>(args)...);
}

}  