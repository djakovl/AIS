# Integration test: Health endpoint returns 200
# Given-When-Then format
# Requires S3 service running (default: http://localhost:8080)

set -e

BASE_URL="${S3_SERVICE_URL:-http://localhost:8080}"
# Given: S3 Storage Service is running and reachable
# When: Client sends GET /health
# Then: Response status is 200 (or 503 if DB/storage degraded) and body is valid JSON

response=$(curl -sS -w "\n%{http_code}" "${BASE_URL}/health" 2>/dev/null) || {
    echo "SKIP: Server not reachable at ${BASE_URL}"
    exit 77
}

body=$(echo "$response" | head -n -1)
status=$(echo "$response" | tail -n 1)

# Health returns 200 when ok, 503 when degraded
if [[ "$status" != "200" && "$status" != "503" ]]; then
    echo "FAIL: Expected status 200 or 503, got ${status}"
    echo "Body: $body"
    exit 1
fi

# Verify JSON shape
if ! echo "$body" | python3 -c "import sys, json; json.load(sys.stdin)" 2>/dev/null; then
    echo "FAIL: Response is not valid JSON"
    echo "Body: $body"
    exit 1
fi

# Prefer 200 for "ok" status
if [[ "$status" == "200" ]]; then
    status_field=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin).get('status', ''))" 2>/dev/null)
    if [[ "$status_field" == "ok" ]]; then
        echo "PASS: Health endpoint returned 200 with status=ok"
        exit 0
    fi
fi

echo "PASS: Health endpoint returned ${status}"
exit 0
