
# Integration test: POST /files/buckets/delete — 400 when bucket has files
# Given: bucket with uploaded file
# When: POST /files/buckets/delete
# Then: 400, success=false
# Requires S3 service running (default: http://localhost:8080)

set -e

BASE_URL="${S3_SERVICE_URL:-http://localhost:8080}"
USER_ID="11111111-2222-3333-4444-555555555557"

TMP_FILE=$(mktemp)
echo "content" > "$TMP_FILE"
trap "rm -f $TMP_FILE" EXIT

# Given: create bucket and upload file
create_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d '{"name":"bucket-with-file"}' \
    "${BASE_URL}/files/buckets/create" 2>/dev/null) || {
    echo "SKIP: Server not reachable at ${BASE_URL}"
    exit 77
}
create_body=$(echo "$create_resp" | head -n -1)
create_status=$(echo "$create_resp" | tail -n 1)
if [[ "$create_status" != "201" ]]; then
    echo "FAIL: Create bucket expected 201, got $create_status"
    exit 1
fi
BUCKET_ID=$(echo "$create_body" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)
curl -sS -X POST -H "X-User-Id: $USER_ID" \
    -F "file=@${TMP_FILE};filename=foo.txt" \
    -F "bucket_id=${BUCKET_ID}" \
    "${BASE_URL}/files/upload" >/dev/null 2>&1 || true

# When: try to delete bucket (has file)
delete_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d "{\"bucketId\": \"$BUCKET_ID\"}" \
    "${BASE_URL}/files/buckets/delete" 2>/dev/null)
delete_body=$(echo "$delete_resp" | head -n -1)
delete_status=$(echo "$delete_resp" | tail -n 1)
if [[ "$delete_status" != "400" ]]; then
    echo "FAIL: Delete non-empty bucket expected 400, got $delete_status"
    echo "$delete_body"
    exit 1
fi
if ! echo "$delete_body" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('success') != False:
    sys.exit(1)
if d.get('error', {}).get('code') != 'BAD_REQUEST':
    sys.exit(2)
" 2>/dev/null; then
    echo "FAIL: Response does not match expected (success=false, error.code=BAD_REQUEST)"
    echo "$delete_body"
    exit 1
fi
echo "PASS: Delete non-empty bucket returns 400"
exit 0
