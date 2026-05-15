# Integration test: DELETE /files/{file_id} — soft delete file (REST-style)
# Given: bucket with uploaded file
# When: DELETE /files/{file_id}
# Then: 200, file not in list
# Requires S3 service running (default: http://localhost:8080)
set -e

BASE_URL="${S3_SERVICE_URL:-http://localhost:8080}"
USER_ID="11111111-2222-3333-4444-555555555555"

# Create temp file for upload
TMP_FILE=$(mktemp)
echo "test content for delete rest" > "$TMP_FILE"
trap "rm -f $TMP_FILE" EXIT

# Given: create bucket
create_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d '{"name":"delete-rest-test-bucket"}' \
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

# Upload file
upload_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "X-User-Id: $USER_ID" \
    -F "file=@${TMP_FILE};filename=test_delete_rest.txt" \
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

# When: DELETE /files/{file_id}
delete_resp=$(curl -sS -w "\n%{http_code}" -X DELETE \
    -H "X-User-Id: $USER_ID" \
    "${BASE_URL}/files/${FILE_ID}" 2>/dev/null)
delete_body=$(echo "$delete_resp" | head -n -1)
delete_status=$(echo "$delete_resp" | tail -n 1)
if [[ "$delete_status" != "200" ]]; then
    echo "FAIL: DELETE /files/{file_id} expected 200, got $delete_status"
    echo "$delete_body"
    exit 1
fi

# Then: verify file not in list (soft delete)
list_resp=$(curl -sS -w "\n%{http_code}" -X GET \
    -H "X-User-Id: $USER_ID" \
    "${BASE_URL}/files/list?bucket_id=${BUCKET_ID}" 2>/dev/null)
list_body=$(echo "$list_resp" | head -n -1)
list_status=$(echo "$list_resp" | tail -n 1)
if [[ "$list_status" != "200" ]]; then
    echo "FAIL: List expected 200, got $list_status"
    exit 1
fi
if FILE_ID="$FILE_ID" echo "$list_body" | python3 -c "
import os, sys, json
d = json.load(sys.stdin)
files = d.get('data', {}).get('files', [])
ids = [f.get('id') for f in files]
target = os.environ.get('FILE_ID', '')
if target in ids:
    sys.exit(1)
" 2>/dev/null; then
    :
else
    echo "FAIL: Deleted file still appears in list"
    echo "$list_body"
    exit 1
fi

echo "PASS: DELETE /files/{file_id} returns 200, file not in list"
exit 0
