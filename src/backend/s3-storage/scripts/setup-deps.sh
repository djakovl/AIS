
# Сборка и зависимости - S3
set -e
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=== Step 1: Install system packages ==="
sudo apt update
sudo apt install -y cmake gcc g++ git libjsoncpp-dev libssl-dev openssl uuid-dev zlib1g-dev libpq-dev postgresql-client gettext

echo "=== Step 2: Install Drogon ==="
if pkg-config --exists libdrogon 2>/dev/null; then
    echo "Drogon already installed."
else
    echo "Installing Drogon via apt..."
    if sudo apt install -y libdrogon-dev 2>/dev/null; then
        echo "Drogon installed via apt."
    else
        echo "Building Drogon from source (v1.9.1)..."
        TMP=$(mktemp -d)
        cd "$TMP"
        git clone --depth 1 --branch v1.9.1 https://github.com/drogonframework/drogon.git
        cd drogon
        git submodule update --init
        mkdir -p build && cd build
        cmake ..
        make -j$(nproc)
        sudo make install
        cd "$PROJECT_DIR"
        rm -rf "$TMP"
    fi
fi

echo "=== Step 3: Generate config.json ==="
export DB_HOST=${DB_HOST:-localhost}
export DB_PORT=${DB_PORT:-5432}
export DB_NAME=${DB_NAME:-s3storage}
export DB_USER=${DB_USER:-s3user}
export DB_PASSWORD=${DB_PASSWORD:-}
export STORAGE_BASE_PATH=${STORAGE_BASE_PATH:-/opt/storage}
envsubst < config.json.template > config.json

echo "=== Step 4: Build project ==="
mkdir -p build && cd build
cmake .. -DBUILD_TESTS=OFF
make -j$(nproc)
cd ..

echo "=== Step 5: Verify ==="
ls -la build/s3-storage-service
echo ""
echo "SUCCESS: Build complete. Executable at build/s3-storage-service"
