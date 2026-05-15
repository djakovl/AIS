# Integration test: POST /files/move — reject when dest bucket not found
# Given: bucket A with file, non-existent bucket UUID
# When: POST /files/move with fileId, newBucketId=non-existent
# Then: 404
set -e

BASE_URL="${S3_SERVICE_URL:-http://localhost:8080}"
USER_ID="11111111-2222-3333-4444-555555555559"

# Non-existent bucket UUID (valid format)
FAKE_BUCKET="00000000-0000-0000-0000-000000000001"

TMP_FILE=$(mktemp)
echo "404 test" > "$TMP_FILE"
trap "rm -f $TMP_FILE" EXIT

# Create bucket A and upload file
create_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d '{"name":"move-404-bucket"}' \
    "${BASE_URL}/files/buckets/create" 2>/dev/null) || {
    echo "SKIP: Server not reachable at ${BASE_URL}"
    exit 77
}
BUCKET_A_ID=$(echo "$create_resp" | head -n -1 | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)

upload_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "X-User-Id: $USER_ID" \
    -F "file=@${TMP_FILE};filename=test.txt" \
    -F "bucket_id=${BUCKET_A_ID}" \
    "${BASE_URL}/files/upload" 2>/dev/null)
FILE_ID=$(echo "$upload_resp" | head -n -1 | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)

# Move to non-existent bucket
move_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d "{\"fileId\":\"$FILE_ID\",\"newBucketId\":\"$FAKE_BUCKET\"}" \
    "${BASE_URL}/files/move" 2>/dev/null)
move_status=$(echo "$move_resp" | tail -n 1)
if [[ "$move_status" != "404" ]]; then
    echo "FAIL: Move to non-existent bucket expected 404, got $move_status"
    echo "$(echo "$move_resp" | head -n -1)"
    exit 1
fi

echo "PASS: Dest bucket not found returns 404"
exit 0
