# S3 Storage Service — Verification Guide

This document describes how to verify that the S3 Storage Service works correctly: build, unit tests, integration tests, and manual smoke checks.

---

## Quick Verification

For a full automated run (build → unit tests → docker-compose stack → integration tests):

```bash
./scripts/verify-all.sh
```

Options:
- `--no-docker` — Skip docker-compose; assume the service is already running
- `--build-only` — Stop after build and unit tests (no integration)
- `--cleanup` — Run `docker compose down` when done

Environment: `S3_SERVICE_URL` (default: `http://localhost:8080`)

---

## Prerequisites

| Requirement | Description |
|-------------|-------------|
| **OS** | Linux |
| **Build** | CMake 3.14+, C++17 compiler (GCC 9+, Clang 10+) |
| **Dependencies** | Drogon framework, libpq (PostgreSQL client) |
| **Database** | PostgreSQL 15+ (locally or via Docker) |
| **Optional** | Docker + docker-compose (for full stack) |
| **Tools** | `curl`, `python3` (for integration tests) |

No hardcoded passwords. Use `.env.example` as a template and set `DB_PASSWORD` (and other vars) in `.env` or environment.

---

## Step-by-Step Verification

### 1. Build

```bash
# Generate config from env (no hardcoded passwords)
envsubst < config.json.template > config.json

mkdir -p build && cd build
cmake .. -DBUILD_TESTS=ON
make
```

### 2. Unit Tests

```bash
cd build
ctest -E "integration_" --output-on-failure
```

Runs Google Test unit tests (UUIDGenerator, ResponseHelper, GatewayAuthFilter).

### 3. Start Stack (docker-compose)

```bash
# From project root, with .env containing DB_PASSWORD
docker compose up -d

# Wait for health endpoint (up to ~60s)
curl -sf http://localhost:8080/health
```

### 4. Integration Tests

Requires the service to be running (e.g. via docker-compose or manual start).

```bash
cd build
export S3_SERVICE_URL=http://localhost:8080
ctest -R "integration_" --output-on-failure
```

Integration tests use exit code 77 to skip when the server is unreachable.

### 5. Manual Smoke Checks

See the [Smoke Checklist](#smoke-checklist) below.

---

## Integration Tests Reference Table

| Test Name | Description |
|-----------|-------------|
| `integration_health` | GET /health returns 200 or 503, valid JSON |
| `integration_gateway_auth` | POST /files/buckets/create without X-User-Id → 401, UNAUTHORIZED |
| `integration_delete_file` | POST /files/delete soft-deletes file, 200; file not in list |
| `integration_delete_file_404` | POST /files/delete with non-existent fileId → 404, NOT_FOUND |
| `integration_delete_bucket` | POST /files/buckets/delete soft-deletes empty bucket, 200 |
| `integration_delete_bucket_400` | POST /files/buckets/delete on bucket with files → 400, BAD_REQUEST |
| `integration_delete_401` | All delete endpoints without X-User-Id → 401 (POST /files/delete, POST /files/buckets/delete, DELETE /files/{id}, DELETE /files/buckets/{id}) |
| `integration_delete_file_rest` | DELETE /files/{file_id} soft-deletes file, 200 |
| `integration_delete_bucket_rest` | DELETE /files/buckets/{bucket_id} soft-deletes empty bucket, 200 |
| `integration_delete_file_rest_404` | DELETE /files/{file_id} with non-existent id → 404, NOT_FOUND |
| `integration_delete_file_rest_400` | DELETE /files/{file_id} with invalid UUID in path → 400, BAD_REQUEST |

---

## Smoke Checklist
 std::function<void(const std::shared_ptr<drogon::orm::Transaction>&)>&
            ca
Manual checks to confirm the API behaves as expected:

| Check | Command | Expected |
|-------|---------|----------|
| **Health** | `curl -s http://localhost:8080/health` | 200, `{"status":"ok",...}` |
| **Auth 401** | `curl -s -X GET http://localhost:8080/files/buckets/list` (no X-User-Id) | 401, `success: false`, `error.code: "UNAUTHORIZED"` |
| **Buckets list 200** | `curl -s -H "X-User-Id: $(uuidgen)" http://localhost:8080/files/buckets/list` | 200, `success: true`, `data.buckets` array |
| **Create bucket** | `curl -s -X POST -H "Content-Type: application/json" -H "X-User-Id: $(uuidgen)" -d '{"name":"smoke-bucket"}' http://localhost:8080/files/buckets/create` | 201, `success: true`, `data.id` |
| **DELETE file** | `curl -s -X DELETE -H "X-User-Id: $(uuidgen)" http://localhost:8080/files/00000000-0000-0000-0000-000000000001` | 404 (non-existent) or 200 (if exists) |
| **DELETE bucket** | `curl -s -X DELETE -H "X-User-Id: $(uuidgen)" http://localhost:8080/files/buckets/00000000-0000-0000-0000-000000000001` | 404 (non-existent) or 200 (if empty) |
| **Swagger UI** | `curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/swagger` | 200 (hidden when PRODUCTION=true) |

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `cmake` fails | Install Drogon, libpq; ensure C++17 compiler |
| `config.json` missing | Run `envsubst < config.json.template > config.json` with env vars set |
| Unit tests fail | Ensure `BUILD_TESTS=ON` in cmake; check GTest |
| Integration tests skip (77) | Service not running — start via `docker compose up -d` or run binary manually |
| `docker compose up` fails | Check `.env` has `DB_PASSWORD`; PostgreSQL port 5432 free |
| 401 on all endpoints | Add `X-User-Id: <uuid>` header |
| Health returns 503 | DB or storage unreachable — check PostgreSQL, STORAGE_BASE_PATH |
| Connection refused | Service not listening on expected port; check 8080 vs 3002 (external) |

---

## Environment and Security

- Use `.env.example` as a template; copy to `.env` and set values.
- Never hardcode passwords in `config.json`; use `envsubst` with `${DB_PASSWORD}` etc.
- `config.json` is generated from `config.json.template` and should not contain secrets in version control.
