#!/usr/bin/env sh
set -eu

BASE_DIR="${RIG_SERVER_BASE:-$HOME/cc-rig-server}"
APP_DIR="${RIG_SERVER_DIR:-$BASE_DIR/cc-rig}"
HOST="${RIG_HOST:-0.0.0.0}"
PORT="${RIG_PORT:-8000}"

cd "$APP_DIR/rig-hub"

detect_lan_ip() {
  if command -v ipconfig >/dev/null 2>&1; then
    ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true
  elif command -v hostname >/dev/null 2>&1; then
    hostname -I 2>/dev/null | awk '{print $1}' || true
  fi
}

LAN_IP="$(detect_lan_ip)"
if [ -z "$LAN_IP" ]; then
  LAN_IP="127.0.0.1"
fi

print_urls() {
  echo "Local: http://127.0.0.1:$PORT"
  echo "LAN:   http://$LAN_IP:$PORT"
}

if [ ! -d ".venv" ]; then
  echo "Missing .venv. Run install-rig-server.sh first." >&2
  exit 1
fi

. .venv/bin/activate

export RIG_DB="${RIG_DB:-$APP_DIR/rig-hub/data/rig.db}"
export RIG_PACKAGES_DIR="${RIG_PACKAGES_DIR:-$APP_DIR/rig-hub/packages}"

mkdir -p "$(dirname "$RIG_DB")"

if curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
  echo "RIG Hub already running."
  print_urls
  exit 0
fi

echo "Starting RIG Hub..."
print_urls

exec uvicorn app.main:app --host "$HOST" --port "$PORT"
