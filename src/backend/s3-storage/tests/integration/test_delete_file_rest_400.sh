# Integration test: DELETE /files/{file_id} — 400 for invalid UUID in path
# When: DELETE /files/not-a-valid-uuid
# Then: 400, success=false, error.code=BAD_REQUEST
# Requires S3 service running (default: http://localhost:8080)
#

set -e

BASE_URL="${S3_SERVICE_URL:-http://localhost:8080}"
USER_ID="11111111-2222-3333-4444-555555555555"

response=$(curl -sS -w "\n%{http_code}" -X DELETE \
    -H "X-User-Id: $USER_ID" \
    "${BASE_URL}/files/not-a-valid-uuid" 2>/dev/null) || {
    echo "SKIP: Server not reachable at ${BASE_URL}"
    exit 77
}

body=$(echo "$response" | head -n -1)
status=$(echo "$response" | tail -n 1)
if [[ "$status" != "400" ]]; then
    echo "FAIL: Expected status 400 for invalid UUID, got ${status}"
    echo "Body: $body"
    exit 1
fi
if ! echo "$body" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('success') != False:
    sys.exit(1)
if d.get('error', {}).get('code') != 'BAD_REQUEST':
    sys.exit(2)
" 2>/dev/null; then
    echo "FAIL: Response does not match expected error shape (success=false, error.code=BAD_REQUEST)"
    echo "Body: $body"
    exit 1
fi
echo "PASS: DELETE /files/{file_id} with invalid UUID returns 400 with BAD_REQUEST"
exit 0
