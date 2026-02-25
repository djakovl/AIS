
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S3_SERVICE_URL="${S3_SERVICE_URL:-http://localhost:8080}"
NON_EXISTENT_BUCKET="${NON_EXISTENT_BUCKET:-00000000-0000-0000-0000-000000000000}"
USER_ID="${REPRO_USER_ID:-11111111-2222-3333-4444-555555555555}"

COUNT=50
PARALLEL=1
VERBOSE=false

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Reproduce segfault: multiple DELETE /files/buckets/{bucket_id} with non-existent bucket.

Options:
  -c, --count N      Number of requests (default: 50, min: 10)
  -p, --parallel N   Parallel clients 1–5 (default: 1 = sequential)
  -v, --verbose      Show curl output
  -h, --help         Show this help

Environment:
  S3_SERVICE_URL         Base URL (default: http://localhost:8080)
  NON_EXISTENT_BUCKET    Bucket UUID to delete (default: 00000000-0000-0000-0000-000000000000)
  REPRO_USER_ID          X-User-Id header (default: 11111111-2222-3333-4444-555555555555)

Examples:
  $0                          # 50 sequential DELETE
  $0 -c 100 -p 1              # 100 sequential
  $0 -c 50 -p 3               # 50 requests, 3 parallel clients
  $0 -c 30 -p 5 -v            # 30 requests, 5 parallel, verbose
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--count)
            COUNT="$2"
            shift 2
            ;;
        -p|--parallel)
            PARALLEL="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate
if [[ ! "$COUNT" =~ ^[0-9]+$ ]] || [[ "$COUNT" -lt 10 ]]; then
    echo "Error: count must be >= 10"
    exit 1
fi
if [[ ! "$PARALLEL" =~ ^[0-9]+$ ]] || [[ "$PARALLEL" -lt 1 ]] || [[ "$PARALLEL" -gt 5 ]]; then
    echo "Error: parallel must be 1–5"
    exit 1
fi

CURL_SILENT=""
if ! $VERBOSE; then
    CURL_SILENT="-s"
fi

echo "=== Segfault reproduction script ==="
echo "URL:        ${S3_SERVICE_URL}"
echo "Bucket:     ${NON_EXISTENT_BUCKET}"
echo "Requests:   ${COUNT}"
echo "Parallel:   ${PARALLEL}"
echo ""

# Check service is reachable
if ! curl -sf "${S3_SERVICE_URL}/health" >/dev/null 2>&1; then
    echo "Error: service not reachable at ${S3_SERVICE_URL}/health"
    echo "Start the service first (see scripts/SEGFAULT_REPRODUCTION.md)"
    exit 1
fi
echo "Service reachable."
echo ""

do_delete() {
    local i="$1"
    curl $CURL_SILENT -X DELETE \
        "${S3_SERVICE_URL}/files/buckets/${NON_EXISTENT_BUCKET}" \
        -H "X-User-Id: ${USER_ID}" \
        -H "X-Request-Id: req-${i}" \
        -w "\n" -o /dev/null || true
}

if [[ "$PARALLEL" -eq 1 ]]; then
    echo "Running ${COUNT} sequential DELETE requests..."
    for i in $(seq 1 "$COUNT"); do
        do_delete "$i"
        if [[ $((i % 10)) -eq 0 ]]; then
            echo "  Progress: $i/$COUNT"
        fi
    done
else
    echo "Running ${COUNT} requests with ${PARALLEL} parallel clients..."
    for i in $(seq 1 "$COUNT"); do
        do_delete "$i" &
        while [[ $(jobs -r -p 2>/dev/null | wc -l) -ge "$PARALLEL" ]]; do
            wait -n 2>/dev/null || sleep 0.05
        done
    done
    wait
fi

echo ""
echo "Done. Check .debug/debug-3c330a.log for NDJSON trace (if DEBUG_S3_SESSION=3c330a)."
echo "If segfault occurred, the log contains the trace up to the crash."
