
# Integration test: delete endpoints — 401 without X-User-Id
# When: Client sends delete (POST or DELETE) without X-User-Id
# Then: 401, success=false, error.code=UNAUTHORIZED
# Covers: POST /files/delete, POST /files/buckets/delete,
#         DELETE /files/{file_id}, DELETE /files/buckets/{bucket_id}
# Requires S3 service running (default: http://localhost:8080)
#

set -e

BASE_URL="${S3_SERVICE_URL:-http://localhost:8080}"
FAKE_ID="11111111-2222-3333-4444-555555555558"

# POST /files/delete without X-User-Id
resp1=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "{\"fileId\": \"$FAKE_ID\"}" \
    "${BASE_URL}/files/delete" 2>/dev/null) || {
    echo "SKIP: Server not reachable at ${BASE_URL}"
    exit 77
}
body1=$(echo "$resp1" | head -n -1)
status1=$(echo "$resp1" | tail -n 1)
if [[ "$status1" != "401" ]]; then
    echo "FAIL: POST /files/delete without X-User-Id expected 401, got $status1"
    echo "$body1"
    exit 1
fi
if ! echo "$body1" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('success') != False:
    sys.exit(1)
if d.get('error', {}).get('code') != 'UNAUTHORIZED':
    sys.exit(2)
" 2>/dev/null; then
    echo "FAIL: POST /files/delete response does not match expected error shape (success=false, error.code=UNAUTHORIZED)"
    echo "Body: $body1"
    exit 1
fi

# POST /files/buckets/delete without X-User-Id
resp2=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "{\"bucketId\": \"$FAKE_ID\"}" \
    "${BASE_URL}/files/buckets/delete" 2>/dev/null)
body2=$(echo "$resp2" | head -n -1)
status2=$(echo "$resp2" | tail -n 1)
if [[ "$status2" != "401" ]]; then
    echo "FAIL: POST /files/buckets/delete without X-User-Id expected 401, got $status2"
    echo "$body2"
    exit 1
fi
if ! echo "$body2" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('success') != False:
    sys.exit(1)
if d.get('error', {}).get('code') != 'UNAUTHORIZED':
    sys.exit(2)
" 2>/dev/null; then
    echo "FAIL: POST /files/buckets/delete response does not match expected error shape (success=false, error.code=UNAUTHORIZED)"
    echo "Body: $body2"
    exit 1
fi

# DELETE /files/{file_id} without X-User-Id
resp3=$(curl -sS -w "\n%{http_code}" -X DELETE \
    "${BASE_URL}/files/${FAKE_ID}" 2>/dev/null)
body3=$(echo "$resp3" | head -n -1)
status3=$(echo "$resp3" | tail -n 1)
if [[ "$status3" != "401" ]]; then
    echo "FAIL: DELETE /files/{file_id} without X-User-Id expected 401, got $status3"
    echo "$body3"
    exit 1
fi
if ! echo "$body3" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('success') != False:
    sys.exit(1)
if d.get('error', {}).get('code') != 'UNAUTHORIZED':
    sys.exit(2)
" 2>/dev/null; then
    echo "FAIL: DELETE /files/{file_id} response does not match expected error shape"
    echo "Body: $body3"
    exit 1
fi

# DELETE /files/buckets/{bucket_id} without X-User-Id
resp4=$(curl -sS -w "\n%{http_code}" -X DELETE \
    "${BASE_URL}/files/buckets/${FAKE_ID}" 2>/dev/null)
body4=$(echo "$resp4" | head -n -1)
status4=$(echo "$resp4" | tail -n 1)
if [[ "$status4" != "401" ]]; then
    echo "FAIL: DELETE /files/buckets/{bucket_id} without X-User-Id expected 401, got $status4"
    echo "$body4"
    exit 1
fi
if ! echo "$body4" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('success') != False:
    sys.exit(1)
if d.get('error', {}).get('code') != 'UNAUTHORIZED':
    sys.exit(2)
" 2>/dev/null; then
    echo "FAIL: DELETE /files/buckets/{bucket_id} response does not match expected error shape"
    echo "Body: $body4"
    exit 1
fi

echo "PASS: All delete endpoints (POST and DELETE) return 401 without X-User-Id"
exit 0
