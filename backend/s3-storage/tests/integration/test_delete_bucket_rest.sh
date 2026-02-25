# Integration test: DELETE /files/buckets/{bucket_id} — soft delete empty bucket
# Given: empty bucket
# When: DELETE /files/buckets/{bucket_id}
# Then: 200, bucket not in list
# Requires S3 service running (default: http://localhost:8080)

set -e

BASE_URL="${S3_SERVICE_URL:-http://localhost:8080}"
USER_ID="11111111-2222-3333-4444-555555555556"

# Given: create empty bucket
create_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d '{"name":"delete-bucket-rest-test"}' \
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

# When: DELETE /files/buckets/{bucket_id}
delete_resp=$(curl -sS -w "\n%{http_code}" -X DELETE \
    -H "X-User-Id: $USER_ID" \
    "${BASE_URL}/files/buckets/${BUCKET_ID}" 2>/dev/null)
delete_body=$(echo "$delete_resp" | head -n -1)
delete_status=$(echo "$delete_resp" | tail -n 1)
if [[ "$delete_status" != "200" ]]; then
    echo "FAIL: DELETE /files/buckets/{bucket_id} expected 200, got $delete_status"
    echo "$delete_body"
    exit 1
fi

# Then: verify bucket not in list
list_resp=$(curl -sS -w "\n%{http_code}" -X GET \
    -H "X-User-Id: $USER_ID" \
    "${BASE_URL}/files/buckets/list" 2>/dev/null)
list_body=$(echo "$list_resp" | head -n -1)
list_status=$(echo "$list_resp" | tail -n 1)
if [[ "$list_status" != "200" ]]; then
    echo "FAIL: List buckets expected 200, got $list_status"
    exit 1
fi
if echo "$list_body" | python3 -c "
import sys, json
d = json.load(sys.stdin)
buckets = d.get('data', {}).get('buckets', [])
ids = [b.get('id') for b in buckets]
target = '$BUCKET_ID'
if target in ids:
    sys.exit(1)
" 2>/dev/null; then
    :
else
    echo "FAIL: Deleted bucket still appears in list"
    echo "$list_body"
    exit 1
fi
echo "PASS: DELETE /files/buckets/{bucket_id} returns 200, bucket not in list"
exit 0
