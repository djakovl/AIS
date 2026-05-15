# Integration test: POST /files/move — cross-bucket move to folder
# Given: bucket A with file, bucket B with folder
# When: POST /files/move with fileId, newBucketId=B, newParentFolderId=folder in B
# Then: 200, file appears in folder in B, gone from A

set -e

BASE_URL="${S3_SERVICE_URL:-http://localhost:8080}"
USER_ID="11111111-2222-3333-4444-555555555556"

TMP_FILE=$(mktemp)
echo "cross-bucket folder test" > "$TMP_FILE"
trap "rm -f $TMP_FILE" EXIT

# Create bucket A
create_a=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d '{"name":"move-bucket-a2"}' \
    "${BASE_URL}/files/buckets/create" 2>/dev/null) || {
    echo "SKIP: Server not reachable at ${BASE_URL}"
    exit 77
}
BUCKET_A_ID=$(echo "$create_a" | head -n -1 | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)

# Create bucket B
create_b=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d '{"name":"move-bucket-b2"}' \
    "${BASE_URL}/files/buckets/create" 2>/dev/null)
BUCKET_B_ID=$(echo "$create_b" | head -n -1 | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)

# Create folder in bucket B
folder_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d "{\"bucketId\":\"$BUCKET_B_ID\",\"name\":\"dest_folder\"}" \
    "${BASE_URL}/files/folders/create" 2>/dev/null)
FOLDER_ID=$(echo "$folder_resp" | head -n -1 | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)
if [[ -z "$FOLDER_ID" ]]; then
    echo "FAIL: Could not create folder in B"
    exit 1
fi

# Upload file to bucket A
upload_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "X-User-Id: $USER_ID" \
    -F "file=@${TMP_FILE};filename=to_folder.txt" \
    -F "bucket_id=${BUCKET_A_ID}" \
    "${BASE_URL}/files/upload" 2>/dev/null)
FILE_ID=$(echo "$upload_resp" | head -n -1 | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)

# Move file from A to folder in B
move_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d "{\"fileId\":\"$FILE_ID\",\"newBucketId\":\"$BUCKET_B_ID\",\"newParentFolderId\":\"$FOLDER_ID\"}" \
    "${BASE_URL}/files/move" 2>/dev/null)
move_status=$(echo "$move_resp" | tail -n 1)
if [[ "$move_status" != "200" ]]; then
    echo "FAIL: Move expected 200, got $move_status"
    echo "$(echo "$move_resp" | head -n -1)"
    exit 1
fi

# Verify file in folder in B (list with parent_folder_id)
list_resp=$(curl -sS -X GET \
    -H "X-User-Id: $USER_ID" \
    "${BASE_URL}/files/list?bucket_id=${BUCKET_B_ID}&parent_folder_id=${FOLDER_ID}" 2>/dev/null)
if ! echo "$list_resp" | python3 -c "
import sys, json
d = json.load(sys.stdin)
files = d.get('data', {}).get('files', [])
ids = [f.get('id') for f in files]
target = sys.argv[1]
sys.exit(0 if target in ids else 1)
" "$FILE_ID" 2>/dev/null; then
    echo "FAIL: File not found in folder in bucket B"
    echo "$list_resp"
    exit 1
fi

# Verify file is gone from bucket A
list_a=$(curl -sS -X GET \
    -H "X-User-Id: $USER_ID" \
    "${BASE_URL}/files/list?bucket_id=${BUCKET_A_ID}" 2>/dev/null)
if echo "$list_a" | python3 -c "
import sys, json
d = json.load(sys.stdin)
files = d.get('data', {}).get('files', [])
ids = [f.get('id') for f in files]
target = sys.argv[1]
sys.exit(0 if target in ids else 1)
" "$FILE_ID" 2>/dev/null; then
    echo "FAIL: File still in bucket A after move"
    exit 1
fi

echo "PASS: Cross-bucket move to folder"
exit 0
