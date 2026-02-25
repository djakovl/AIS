# Integration test: POST /files/move — reject when dest bucket quota exceeded
# Given: bucket A with file, bucket B with storage_limit set small (via DB)
# When: POST /files/move file from A to B (file size > remaining quota)
# Then: 403 (quota exceeded)
# Requires: DB access (DB_HOST, DB_NAME, DB_USER, PGPASSWORD or DB_PASSWORD)
set -e

BASE_URL="${S3_SERVICE_URL:-http://localhost:8080}"
USER_ID="11111111-2222-3333-4444-555555555560"

# Check DB env for psql
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-s3storage}"
DB_USER="${DB_USER:-s3user}"
DB_PASS="${PGPASSWORD:-$DB_PASSWORD}"

if [[ -z "$DB_PASS" ]]; then
    echo "SKIP: DB_PASSWORD or PGPASSWORD not set (quota test requires DB access)"
    exit 77
fi

export PGPASSWORD="$DB_PASS"

# Create bucket A
create_a=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d '{"name":"quota-bucket-a"}' \
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
    -d '{"name":"quota-bucket-b"}' \
    "${BASE_URL}/files/buckets/create" 2>/dev/null)
BUCKET_B_ID=$(echo "$create_b" | head -n -1 | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)

# Set bucket B quota: limit=100, used=80 (20 bytes remaining)
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c \
    "UPDATE buckets SET storage_limit=100, storage_used=80 WHERE id='$BUCKET_B_ID' AND deleted_at IS NULL;" 2>/dev/null || {
    echo "SKIP: Cannot connect to DB (psql failed)"
    exit 77
}

# Create file ~50 bytes in bucket A
TMP_FILE=$(mktemp)
echo "0123456789012345678901234567890123456789012345678" > "$TMP_FILE"
trap "rm -f $TMP_FILE" EXIT

upload_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "X-User-Id: $USER_ID" \
    -F "file=@${TMP_FILE};filename=big_enough.txt" \
    -F "bucket_id=${BUCKET_A_ID}" \
    "${BASE_URL}/files/upload" 2>/dev/null)
FILE_ID=$(echo "$upload_resp" | head -n -1 | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('data', {}).get('id', ''))
" 2>/dev/null)

# Move to B — should fail with 403 (50 > 20 remaining)
move_resp=$(curl -sS -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-Id: $USER_ID" \
    -d "{\"fileId\":\"$FILE_ID\",\"newBucketId\":\"$BUCKET_B_ID\"}" \
    "${BASE_URL}/files/move" 2>/dev/null)
move_status=$(echo "$move_resp" | tail -n 1)
if [[ "$move_status" != "403" ]]; then
    echo "FAIL: Quota exceeded expected 403, got $move_status"
    echo "$(echo "$move_resp" | head -n -1)"
    exit 1
fi

echo "PASS: Quota exceeded returns 403"
exit 0
