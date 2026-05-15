# Integration test: POST /files/move — same-bucket move (no newBucketId)
# Given: bucket with file and folder
# When: POST /files/move with fileId, newParentFolderId only (no newBucketId)
# Then: 200, file moved within bucket
set -e

BASE_URL="${S3_SERVICE_URL:-http://localhost:8080}"
USER_ID="11111111-2222-3333-4444-555555555557"

TMP_FILE=$(mktemp)
echo "same-bucket move test" > "$TMP_FILE"
trap "rm -f $TMP_FILE" EXIT

# Create bucket
create_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d '{"name":"move-same-bucket"}' \
    "${BASE_URL}/files/buckets/create" 2>/dev/null) || {
    echo "SKIP: Server not reachable at ${BASE_URL}"
    exit 77
}
BUCKET_ID=$(echo "$create_resp" | head -n -1 | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)

# Create folder
folder_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d "{\"bucketId\":\"$BUCKET_ID\",\"name\":\"target_folder\"}" \
    "${BASE_URL}/files/folders/create" 2>/dev/null)
FOLDER_ID=$(echo "$folder_resp" | head -n -1 | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)

# Upload file to root
upload_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "X-User-Id: $USER_ID" \
    -F "file=@${TMP_FILE};filename=at_root.txt" \
    -F "bucket_id=${BUCKET_ID}" \
    "${BASE_URL}/files/upload" 2>/dev/null)
FILE_ID=$(echo "$upload_resp" | head -n -1 | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)

# Same-bucket move: fileId + newParentFolderId only (no newBucketId)
move_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d "{\"fileId\":\"$FILE_ID\",\"newParentFolderId\":\"$FOLDER_ID\"}" \
    "${BASE_URL}/files/move" 2>/dev/null)
move_status=$(echo "$move_resp" | tail -n 1)
if [[ "$move_status" != "200" ]]; then
    echo "FAIL: Same-bucket move expected 200, got $move_status"
    echo "$(echo "$move_resp" | head -n -1)"
    exit 1
fi

# Verify file in folder
list_resp=$(curl -sS -X GET \
    -H "X-User-Id: $USER_ID" \
    "${BASE_URL}/files/list?bucket_id=${BUCKET_ID}&parent_folder_id=${FOLDER_ID}" 2>/dev/null)
if ! echo "$list_resp" | python3 -c "
import sys, json
d = json.load(sys.stdin)
files = d.get('data', {}).get('files', [])
ids = [f.get('id') for f in files]
target = sys.argv[1]
sys.exit(0 if target in ids else 1)
" "$FILE_ID" 2>/dev/null; then
    echo "FAIL: File not found in folder after same-bucket move"
    echo "$list_resp"
    exit 1
fi

echo "PASS: Same-bucket move works"
exit 0
