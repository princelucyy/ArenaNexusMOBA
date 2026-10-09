#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

PYTHON_BIN="$(command -v python3 || command -v python || true)"
if [ -z "$PYTHON_BIN" ]; then
  echo "Python belum terpasang di Termux." >&2
  echo "Jalankan: pkg update && pkg install python -y" >&2
  exit 127
fi

# Use an isolated environment so dependency installs do not conflict with Termux packages.
if [ -d /data/data/com.termux/files/usr ] || command -v termux-info >/dev/null 2>&1; then
  if [ ! -x .venv/bin/python ]; then
    "$PYTHON_BIN" -m venv .venv
  fi
  PYTHON_BIN="$PWD/.venv/bin/python"
fi

"$PYTHON_BIN" -m pip install -q -r requirements.txt
export ASTRO_HOST="${ASTRO_HOST:-0.0.0.0}"
export ASTRO_PORT="${ASTRO_PORT:-8787}"
export ASTRO_WS_PORT="${ASTRO_WS_PORT:-8788}"
export MATCHMAKING_MIN_PLAYERS="${MATCHMAKING_MIN_PLAYERS:-10}"
export ASTRO_DB="${ASTRO_DB:-$PWD/astro_royale_v35.sqlite3}"
exec "$PYTHON_BIN" main.py
