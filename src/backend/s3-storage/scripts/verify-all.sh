
# Full verification script for S3 Storage Service
# Runs: build -> unit tests -> (optional) stack start -> integration tests

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
S3_SERVICE_URL="${S3_SERVICE_URL:-http://localhost:8080}"

NO_DOCKER=false
BUILD_ONLY=false
CLEANUP=false

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Full verification: build, unit tests, (optional) stack start, integration tests.

Options:
  --no-docker    Skip docker-compose; assume service is already running.
                 Runs build + unit + integration.
  --build-only   Stop after unit tests (no stack start, no integration).
  --cleanup      Run 'docker compose down' when done.
  --help         Show this help.

Environment:
  S3_SERVICE_URL  Base URL for S3 service (default: http://localhost:8080)

Examples:
  $0                  # Full run: build, unit, start stack, integration
  $0 --no-docker      # Build, unit, integration (service already running)
  $0 --build-only     # Build and unit tests only
  $0 --cleanup        # Full run and tear down stack at end
EOF
}

for arg in "$@"; do
    case "$arg" in
        --no-docker)   NO_DOCKER=true ;;
        --build-only)  BUILD_ONLY=true ;;
        --cleanup)     CLEANUP=true ;;
        --help|-h)     usage; exit 0 ;;
        *)
            echo "Unknown option: $arg"
            usage
            exit 1
            ;;
    esac
done

run_step() {
    local step_name="$1"
    echo ""
    echo "=== $step_name ==="
}

fail() {
    echo ""
    echo "FAIL: $1"
    exit 1
}

#Build
run_step "Step 1: Build"
cd "$PROJECT_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
cmake .. -DBUILD_TESTS=ON || fail "cmake failed"
make -j$(nproc) || fail "make failed"
echo "Build OK"

#Unit tests
run_step "Step 2: Unit tests"
ctest -E "integration_" --output-on-failure || fail "Unit tests failed"
echo "Unit tests OK"

if "$BUILD_ONLY"; then
    echo ""
    echo "SUCCESS: Build and unit tests passed (--build-only)"
    exit 0
fi

#Stack start (unless --no-docker)
if ! "$NO_DOCKER"; then
    run_step "Step 3: Start stack (docker compose)"
    cd "$PROJECT_DIR"
    if ! command -v docker &>/dev/null; then
        fail "docker not found"
    fi
    if docker compose version &>/dev/null; then
        DOCKER_COMPOSE="docker compose"
    elif docker-compose --version &>/dev/null; then
        DOCKER_COMPOSE="docker-compose"
    else
        fail "docker compose or docker-compose not found"
    fi
    $DOCKER_COMPOSE up -d || fail "docker compose up failed"

    # Wait for health endpoint (up to 60s)
    echo "Waiting for service at ${S3_SERVICE_URL}/health..."
    for i in $(seq 1 30); do
        if curl -sf "${S3_SERVICE_URL}/health" >/dev/null 2>&1; then
            echo "Service ready"
            break
        fi
        if [[ $i -eq 30 ]]; then
            fail "Service did not become ready in 60 seconds"
        fi
        sleep 2
    done
    echo "Stack OK"
else
    run_step "Step 3: Stack (skipped, --no-docker)"
    # Quick health check to warn if service is not reachable
    if ! curl -sf "${S3_SERVICE_URL}/health" >/dev/null 2>&1; then
        fail "Service not reachable at ${S3_SERVICE_URL} (use --no-docker only when service is already running)"
    fi
    echo "Service reachable"
fi

# Integration tests
run_step "Step 4: Integration tests"
cd "$BUILD_DIR"
export S3_SERVICE_URL
ctest -R "integration_" --output-on-failure || fail "Integration tests failed"
echo "Integration tests OK"

# Cleanup (if --cleanup)
if "$CLEANUP" && ! "$NO_DOCKER"; then
    run_step "Step 5: Cleanup"
    cd "$PROJECT_DIR"
    $DOCKER_COMPOSE down || true
    echo "Cleanup OK"
fi

echo ""
echo "SUCCESS: Full verification passed"
