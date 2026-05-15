# Integration test: POST /files/move — reject folder cross-bucket move
# Given: bucket A with folder, bucket B
# When: POST /files/move with folderId, newBucketId=B
# Then: 400 (folder cross-bucket not supported)
set -e

BASE_URL="${S3_SERVICE_URL:-http://localhost:8080}"
USER_ID="11111111-2222-3333-4444-555555555558"

# Create bucket A
create_a=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d '{"name":"move-folder-bucket-a"}' \
    "${BASE_URL}/files/buckets/create" 2>/dev/null) || {
    echo "SKIP: Server not reachable at ${BASE_URL}"
    exit 77
}
BUCKET_A_ID=$(echo "$create_a" | head -n -1 | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)

# Create folder in bucket A
folder_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d "{\"bucketId\":\"$BUCKET_A_ID\",\"name\":\"a_folder\"}" \
    "${BASE_URL}/files/folders/create" 2>/dev/null)
FOLDER_ID=$(echo "$folder_resp" | head -n -1 | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)

# Create bucket B
create_b=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d '{"name":"move-folder-bucket-b"}' \
    "${BASE_URL}/files/buckets/create" 2>/dev/null)
BUCKET_B_ID=$(echo "$create_b" | head -n -1 | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)

# Try to move folder from A to B — should return 400
move_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d "{\"fileId\":\"$FOLDER_ID\",\"newBucketId\":\"$BUCKET_B_ID\"}" \
    "${BASE_URL}/files/move" 2>/dev/null)
move_body=$(echo "$move_resp" | head -n -1)
move_status=$(echo "$move_resp" | tail -n 1)
if [[ "$move_status" != "400" ]]; then
    echo "FAIL: Folder cross-bucket move expected 400, got $move_status"
    echo "$move_body"
    exit 1
fi
if ! echo "$move_body" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('success') is True:
    sys.exit(1)
err = d.get('error', {})
msg = err.get('message', '').lower()
if 'folder' not in msg and 'bucket' not in msg:
    sys.exit(1)
sys.exit(0)
" 2>/dev/null; then
    echo "FAIL: Expected error message about folder/bucket"
    echo "$move_body"
    exit 1
fi

echo "PASS: Folder cross-bucket move rejected with 400"
exit 0
