# Integration test: POST /files/move — cross-bucket move to root
# Given: bucket A with file, bucket B empty
# When: POST /files/move with fileId, newBucketId=B, newParentFolderId empty
# Then: 200, file appears in B root, gone from A
set -e

BASE_URL="${S3_SERVICE_URL:-http://localhost:8080}"
USER_ID="11111111-2222-3333-4444-555555555555"

TMP_FILE=$(mktemp)
echo "cross-bucket root test" > "$TMP_FILE"
trap "rm -f $TMP_FILE" EXIT

# Create bucket A
create_a=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d '{"name":"move-bucket-a"}' \
    "${BASE_URL}/files/buckets/create" 2>/dev/null) || {
    echo "SKIP: Server not reachable at ${BASE_URL}"
    exit 77
}
BUCKET_A_ID=$(echo "$create_a" | head -n -1 | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)
if [[ -z "$BUCKET_A_ID" ]]; then
    echo "FAIL: Could not create bucket A"
    exit 1
fi

# Create bucket B
create_b=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d '{"name":"move-bucket-b"}' \
    "${BASE_URL}/files/buckets/create" 2>/dev/null)
BUCKET_B_ID=$(echo "$create_b" | head -n -1 | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)
if [[ -z "$BUCKET_B_ID" ]]; then
    echo "FAIL: Could not create bucket B"
    exit 1
fi

# Upload file to bucket A (use document.pdf to match user scenario)
upload_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "X-User-Id: $USER_ID" \
    -F "file=@${TMP_FILE};filename=document.pdf" \
    -F "bucket_id=${BUCKET_A_ID}" \
    "${BASE_URL}/files/upload" 2>/dev/null)
upload_body=$(echo "$upload_resp" | head -n -1)
upload_status=$(echo "$upload_resp" | tail -n 1)
if [[ "$upload_status" != "201" ]]; then
    echo "FAIL: Upload expected 201, got $upload_status"
    exit 1
fi
FILE_ID=$(echo "$upload_body" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)
if [[ -z "$FILE_ID" ]]; then
    echo "FAIL: Could not extract file_id"
    exit 1
fi

# Move file from A to B root (newBucketId set, newParentFolderId empty)
move_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d "{\"fileId\":\"$FILE_ID\",\"newBucketId\":\"$BUCKET_B_ID\"}" \
    "${BASE_URL}/files/move" 2>/dev/null)
move_body=$(echo "$move_resp" | head -n -1)
move_status=$(echo "$move_resp" | tail -n 1)
if [[ "$move_status" != "200" ]]; then
    echo "FAIL: Move expected 200, got $move_status"
    echo "$move_body"
    exit 1
fi

# Verify file in B root, not in A
list_b=$(curl -sS -w "\n%{http_code}" -X GET \
    -H "X-User-Id: $USER_ID" \
    "${BASE_URL}/files/list?bucket_id=${BUCKET_B_ID}" 2>/dev/null)
list_b_body=$(echo "$list_b" | head -n -1)
if ! echo "$list_b_body" | python3 -c "
import sys, json
d = json.load(sys.stdin)
files = d.get('data', {}).get('files', [])
ids = [f.get('id') for f in files]
target = sys.argv[1]
sys.exit(0 if target in ids else 1)
" "$FILE_ID" 2>/dev/null; then
    echo "FAIL: File not found in bucket B"
    echo "$list_b_body"
    exit 1
fi

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

# Round-trip: move B -> A, verify no duplication
move_back=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d "{\"fileId\":\"$FILE_ID\",\"newBucketId\":\"$BUCKET_A_ID\"}" \
    "${BASE_URL}/files/move" 2>/dev/null)
move_back_status=$(echo "$move_back" | tail -n 1)
if [[ "$move_back_status" != "200" ]]; then
    echo "FAIL: Move B->A expected 200, got $move_back_status"
    echo "$move_back" | head -n -1
    exit 1
fi

# List A: must have exactly one file (our document.pdf)
list_a_after=$(curl -sS -X GET \
    -H "X-User-Id: $USER_ID" \
    "${BASE_URL}/files/list?bucket_id=${BUCKET_A_ID}" 2>/dev/null)
count_a=$(echo "$list_a_after" | python3 -c "
import sys, json
d = json.load(sys.stdin)
files = d.get('data', {}).get('files', [])
# Count files named document.pdf
names = [f.get('name') for f in files]
print(names.count('document.pdf'))
" 2>/dev/null)
if [[ "$count_a" != "1" ]]; then
    echo "FAIL: After move B->A, bucket A should have exactly 1 document.pdf, got $count_a"
    echo "$list_a_after"
    exit 1
fi

# List B: must be empty (file moved back to A)
list_b_after=$(curl -sS -X GET \
    -H "X-User-Id: $USER_ID" \
    "${BASE_URL}/files/list?bucket_id=${BUCKET_B_ID}" 2>/dev/null)
if echo "$list_b_after" | python3 -c "
import sys, json
d = json.load(sys.stdin)
files = d.get('data', {}).get('files', [])
ids = [f.get('id') for f in files]
target = sys.argv[1]
sys.exit(0 if target in ids else 1)
" "$FILE_ID" 2>/dev/null; then
    echo "FAIL: File still in bucket B after move B->A"
    echo "$list_b_after"
    exit 1
fi

echo "PASS: Cross-bucket move to root (A->B->A, no duplication)"
exit 0
