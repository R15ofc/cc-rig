#!/usr/bin/env sh
set -eu

REPO_URL="${RIG_REPO_URL:-https://github.com/R15ofc/cc-rig.git}"
BASE_DIR="${RIG_SERVER_BASE:-$HOME/cc-rig-server}"
APP_DIR="${RIG_SERVER_DIR:-$BASE_DIR/cc-rig}"

mkdir -p "$BASE_DIR"

if [ -d "$APP_DIR/.git" ]; then
  cd "$APP_DIR"
  git pull --ff-only
else
  git clone "$REPO_URL" "$APP_DIR"
  cd "$APP_DIR"
fi

cd "$APP_DIR/rig-hub"

python3 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.txt

echo "RIG Hub installed at: $APP_DIR/rig-hub"
echo "Start with: $BASE_DIR/startup-rig-hub.sh"

