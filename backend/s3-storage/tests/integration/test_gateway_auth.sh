# Integration test: GatewayAuthFilter — missing X-User-Id returns 401
# Given-When-Then format
# Requires S3 service running (default: http://localhost:8080)
set -e

BASE_URL="${S3_SERVICE_URL:-http://localhost:8080}"
# Given: S3 Storage Service is running
# When: Client sends POST /files/buckets/create WITHOUT X-User-Id header
# Then: Response status is 401 and body contains success=false, error.code=UNAUTHORIZED

response=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d '{"name":"test-bucket"}' \
    "${BASE_URL}/files/buckets/create" 2>/dev/null) || {
    echo "SKIP: Server not reachable at ${BASE_URL}"
    exit 77
}

body=$(echo "$response" | head -n -1)
status=$(echo "$response" | tail -n 1)

if [[ "$status" != "401" ]]; then
    echo "FAIL: Expected status 401, got ${status}"
    echo "Body: $body"
    exit 1
fi

# Verify error JSON shape
if ! echo "$body" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('success') != False:
    sys.exit(1)
if d.get('error', {}).get('code') != 'UNAUTHORIZED':
    sys.exit(2)
" 2>/dev/null; then
    echo "FAIL: Response does not match expected error shape (success=false, error.code=UNAUTHORIZED)"
    echo "Body: $body"
    exit 1
fi

echo "PASS: Missing X-User-Id returns 401 with UNAUTHORIZED error"
exit 0
