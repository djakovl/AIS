// Implementation of DatabaseService — PostgreSQL connection pool.

#include "services/DatabaseService.h"
#include <drogon/drogon.h>
#include <stdexcept>

namespace s3 {

DatabaseService& DatabaseService::instance() {
    static DatabaseService instance;
    return instance;
}

drogon::orm::DbClientPtr DatabaseService::getClient(const std::string& name) {
    auto client = drogon::app().getDbClient(name);
    if (!client) {
        throw std::runtime_error("DatabaseService: DbClient '" + name +
                                "' not available (check config.json db_clients)");
    }
    return client;
}

std::shared_ptr<drogon::orm::Transaction> DatabaseService::newTransaction(
    const std::function<void(bool)>& commitCallback) {
    return getClient()->newTransaction(commitCallback);
}

void DatabaseService::newTransactionAsync(
    const std::function<void(const std::shared_ptr<drogon::orm::Transaction>&)>&
        callback) {
    getClient()->newTransactionAsync(callback);
}

}  // namespace s3
