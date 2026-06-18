#!/usr/bin/env sh
set -eu

BASE_DIR="${RIG_SERVER_BASE:-$HOME/cc-rig-server}"
APP_DIR="${RIG_SERVER_DIR:-$BASE_DIR/cc-rig}"
HOST="${RIG_HOST:-0.0.0.0}"
PORT="${RIG_PORT:-8000}"

cd "$APP_DIR/rig-hub"

if [ ! -d ".venv" ]; then
  echo "Missing .venv. Run install-rig-server.sh first." >&2
  exit 1
fi

. .venv/bin/activate

export RIG_DB="${RIG_DB:-$APP_DIR/rig-hub/data/rig.db}"
export RIG_PACKAGES_DIR="${RIG_PACKAGES_DIR:-$APP_DIR/rig-hub/packages}"

mkdir -p "$(dirname "$RIG_DB")"

exec uvicorn app.main:app --host "$HOST" --port "$PORT"

