# Integration test: Shared download flow
# Given: bucket with uploaded file, shared link created
# When: GET /files/shared/{token} without X-User-Id
# Then: 200, response body equals uploaded file content
# Requires S3 service running (default: http://localhost:8080)
set -e

BASE_URL="${S3_SERVICE_URL:-http://localhost:8080}"
USER_ID="11111111-2222-3333-4444-555555555555"

# Create temp files
TMP_FILE=$(mktemp)
DOWNLOADED_FILE=$(mktemp)
echo "shared download test content" > "$TMP_FILE"
trap "rm -f $TMP_FILE $DOWNLOADED_FILE" EXIT

# 1. Create bucket (with X-User-Id)
create_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d '{"name":"shared-download-test-bucket"}' \
    "${BASE_URL}/files/buckets/create" 2>/dev/null) || {
    echo "SKIP: Server not reachable at ${BASE_URL}"
    exit 77
}
create_body=$(echo "$create_resp" | head -n -1)
create_status=$(echo "$create_resp" | tail -n 1)
if [[ "$create_status" != "201" ]]; then
    echo "FAIL: Create bucket expected 201, got $create_status"
    echo "$create_body"
    exit 1
fi
BUCKET_ID=$(echo "$create_body" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)
if [[ -z "$BUCKET_ID" ]]; then
    echo "FAIL: Could not extract bucket_id from create response"
    exit 1
fi

# 2. Upload file (with X-User-Id)
upload_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "X-User-Id: $USER_ID" \
    -F "file=@${TMP_FILE};filename=test_shared.txt" \
    -F "bucket_id=${BUCKET_ID}" \
    "${BASE_URL}/files/upload" 2>/dev/null)
upload_body=$(echo "$upload_resp" | head -n -1)
upload_status=$(echo "$upload_resp" | tail -n 1)
if [[ "$upload_status" != "201" ]]; then
    echo "FAIL: Upload expected 201, got $upload_status"
    echo "$upload_body"
    exit 1
fi
FILE_ID=$(echo "$upload_body" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)
if [[ -z "$FILE_ID" ]]; then
    echo "FAIL: Could not extract file_id from upload response"
    exit 1
fi

# 3. POST /files/share/create with fileId (with X-User-Id)
share_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d "{\"fileId\": \"$FILE_ID\"}" \
    "${BASE_URL}/files/share/create" 2>/dev/null)
share_body=$(echo "$share_resp" | head -n -1)
share_status=$(echo "$share_resp" | tail -n 1)
if [[ "$share_status" != "201" ]]; then
    echo "FAIL: Share create expected 201, got $share_status"
    echo "$share_body"
    exit 1
fi
TOKEN=$(echo "$share_body" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('token', ''))
" 2>/dev/null)
if [[ -z "$TOKEN" ]]; then
    echo "FAIL: Could not extract token from share create response"
    exit 1
fi

# 4. GET /files/shared/{token} WITHOUT X-User-Id — save body to temp file
download_out=$(curl -sS -w "\n%{http_code}" -o "$DOWNLOADED_FILE" \
    "${BASE_URL}/files/shared/${TOKEN}" 2>/dev/null)
download_status=$(echo "$download_out" | tail -n 1)
if [[ "$download_status" != "200" ]]; then
    echo "FAIL: Shared download expected 200, got $download_status"
    echo "Response body (first 500 chars):"
    head -c 500 "$DOWNLOADED_FILE" 2>/dev/null || true
    exit 1
fi

# 5. Assert response body matches uploaded file content
if ! cmp -s "$TMP_FILE" "$DOWNLOADED_FILE"; then
    echo "FAIL: Downloaded content does not match original file"
    echo "Original size: $(wc -c < "$TMP_FILE")"
    echo "Downloaded size: $(wc -c < "$DOWNLOADED_FILE")"
    echo "Diff:"
    diff "$TMP_FILE" "$DOWNLOADED_FILE" || true
    exit 1
fi

echo "PASS: Shared download flow works"
exit 0
