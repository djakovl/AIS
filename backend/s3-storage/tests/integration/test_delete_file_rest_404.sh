# Integration test: DELETE /files/{file_id} — 404 for non-existent file
# When: DELETE /files/{file_id} with non-existent file_id
# Then: 404, success=false, error.code=NOT_FOUND
# Requires S3 service running (default: http://localhost:8080)
set -e

BASE_URL="${S3_SERVICE_URL:-http://localhost:8080}"
USER_ID="11111111-2222-3333-4444-555555555555"
# Valid UUID format but non-existent
FAKE_FILE_ID="00000000-0000-0000-0000-000000000099"

response=$(curl -sS -w "\n%{http_code}" -X DELETE \
    -H "X-User-Id: $USER_ID" \
    "${BASE_URL}/files/${FAKE_FILE_ID}" 2>/dev/null) || {
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
echo "PASS: DELETE /files/{file_id} for non-existent file returns 404 with NOT_FOUND"
exit 0
