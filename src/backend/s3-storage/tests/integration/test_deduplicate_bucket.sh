
# Integration test: POST /files/buckets/{bucket_id}/deduplicate
# Given: bucket with duplicate files (upload same file twice with same name)
# When: POST /files/buckets/{bucket_id}/deduplicate
# Then: 200, success=true, removedCount >= 1, removedSize > 0, one dup.pdf in list
# Also: without X-User-Id → 401
# Requires S3 service running (default: http://localhost:8080)

set -e

BASE_URL="${S3_SERVICE_URL:-http://localhost:8080}"
USER_ID="11111111-2222-3333-4444-555555555559"

TMP_FILE=$(mktemp)
echo "duplicate file content for dedup test" > "$TMP_FILE"
trap "rm -f $TMP_FILE" EXIT

#Probe server
curl -sS -o /dev/null "${BASE_URL}/health" 2>/dev/null || {
    echo "SKIP: Server not reachable at ${BASE_URL}"
    exit 77
}

#Test without X-User-Id → 401
FAKE_BUCKET="11111111-2222-3333-4444-555555555550"
resp401=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    "${BASE_URL}/files/buckets/${FAKE_BUCKET}/deduplicate" 2>/dev/null)
body401=$(echo "$resp401" | head -n -1)
status401=$(echo "$resp401" | tail -n 1)
if [[ "$status401" != "401" ]]; then
    echo "FAIL: deduplicate without X-User-Id expected 401, got $status401"
    echo "$body401"
    exit 1
fi
if ! echo "$body401" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('success') != False:
    sys.exit(1)
if d.get('error', {}).get('code') != 'UNAUTHORIZED':
    sys.exit(2)
" 2>/dev/null; then
    echo "FAIL: 401 response does not match expected shape (success=false, error.code=UNAUTHORIZED)"
    echo "Body: $body401"
    exit 1
fi

#Create bucket
create_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d '{"name":"dedup-test-bucket"}' \
    "${BASE_URL}/files/buckets/create" 2>/dev/null)
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

#Upload dup.pdf twice (same filename, same content)
upload1_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "X-User-Id: $USER_ID" \
    -F "file=@${TMP_FILE};filename=dup.pdf" \
    -F "bucket_id=${BUCKET_ID}" \
    "${BASE_URL}/files/upload" 2>/dev/null)
upload1_status=$(echo "$upload1_resp" | tail -n 1)
if [[ "$upload1_status" != "201" ]]; then
    echo "FAIL: First upload expected 201, got $upload1_status"
    echo "$(echo "$upload1_resp" | head -n -1)"
    exit 1
fi

upload2_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "X-User-Id: $USER_ID" \
    -F "file=@${TMP_FILE};filename=dup.pdf" \
    -F "bucket_id=${BUCKET_ID}" \
    "${BASE_URL}/files/upload" 2>/dev/null)
upload2_status=$(echo "$upload2_resp" | tail -n 1)
if [[ "$upload2_status" != "201" ]]; then
    echo "FAIL: Second upload expected 201, got $upload2_status"
    echo "$(echo "$upload2_resp" | head -n -1)"
    exit 1
fi

#GET /files/list — expect 2 entries with name dup.pdf
list_before=$(curl -sS -X GET \
    -H "X-User-Id: $USER_ID" \
    "${BASE_URL}/files/list?bucket_id=${BUCKET_ID}" 2>/dev/null)
dup_count=$(echo "$list_before" | python3 -c "
import sys, json
d = json.load(sys.stdin)
files = d.get('data', {}).get('files', [])
dup = sum(1 for f in files if f.get('name') == 'dup.pdf')
print(dup)
" 2>/dev/null)
if [[ "$dup_count" != "2" ]]; then
    echo "FAIL: Before deduplicate expected 2 entries dup.pdf, got $dup_count"
    echo "$list_before"
    exit 1
fi

#POST /files/buckets/{bucket_id}/deduplicate
dedup_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    "${BASE_URL}/files/buckets/${BUCKET_ID}/deduplicate" 2>/dev/null)
dedup_body=$(echo "$dedup_resp" | head -n -1)
dedup_status=$(echo "$dedup_resp" | tail -n 1)
if [[ "$dedup_status" != "200" ]]; then
    echo "FAIL: deduplicate expected 200, got $dedup_status"
    echo "$dedup_body"
    exit 1
fi
if ! echo "$dedup_body" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('success') != True:
    sys.exit(1)
data = d.get('data', {})
removed = data.get('removedCount', -1)
size = data.get('removedSize', -1)
if removed < 1:
    sys.exit(2)
if size <= 0:
    sys.exit(3)
" 2>/dev/null; then
    echo "FAIL: deduplicate response expected success=true, removedCount >= 1, removedSize > 0"
    echo "Body: $dedup_body"
    exit 1
fi

#GET /files/list — expect 1 entry dup.pdf
list_after=$(curl -sS -X GET \
    -H "X-User-Id: $USER_ID" \
    "${BASE_URL}/files/list?bucket_id=${BUCKET_ID}" 2>/dev/null)
dup_count_after=$(echo "$list_after" | python3 -c "
import sys, json
d = json.load(sys.stdin)
files = d.get('data', {}).get('files', [])
dup = sum(1 for f in files if f.get('name') == 'dup.pdf')
print(dup)
" 2>/dev/null)
if [[ "$dup_count_after" != "1" ]]; then
    echo "FAIL: After deduplicate expected 1 entry dup.pdf, got $dup_count_after"
    echo "$list_after"
    exit 1
fi

echo "PASS: deduplicate returns 200, removedCount >= 1, removedSize > 0; 401 without X-User-Id"
exit 0
