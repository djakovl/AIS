
set -e
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

if [[ ! -f .env.example ]]; then
    echo "Error: .env.example not found."
    exit 1
fi

if [[ ! -f .env ]]; then
    cp .env.example .env
    echo "Created .env from .env.example. Please edit .env and set DB_PASSWORD."
else
    echo ".env already exists. Skipping."
fi
