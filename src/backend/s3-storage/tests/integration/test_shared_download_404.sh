# Integration test: GET /files/shared/{token} — 404 for invalid token
# When: GET /files/shared/invalid-token-12345
# Then: 404, success=false
# Requires S3 service running (default: http://localhost:8080)
set -e

BASE_URL="${S3_SERVICE_URL:-http://localhost:8080}"
INVALID_TOKEN="invalid-token-12345"

response=$(curl -sS -w "\n%{http_code}" \
    "${BASE_URL}/files/shared/${INVALID_TOKEN}" 2>/dev/null) || {
    echo "SKIP: Server not reachable at ${BASE_URL}"
    exit 77
}

body=$(echo "$response" | head -n -1)
status=$(echo "$response" | tail -n 1)
if [[ "$status" != "404" ]]; then
    echo "FAIL: Expected status 404, got ${status}"
    echo "Body: $body"
    exit 1
fi
if ! echo "$body" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('success') != False:
    sys.exit(1)
if d.get('error', {}).get('code') != 'NOT_FOUND':
    sys.exit(2)
" 2>/dev/null; then
    echo "FAIL: Response does not match expected error shape (success=false, error.code=NOT_FOUND)"
    echo "Body: $body"
    exit 1
fi
echo "PASS: Shared download with invalid token returns 404 with NOT_FOUND"
exit 0
