#!/usr/bin/env bash
set -euo pipefail

export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

GAMEDIR="$XDG_DATA_HOME/hytale-launcher"
BIN="$GAMEDIR/hytale-launcher"
METADATA="$GAMEDIR/hytale-launcher-metadata.json"
API="https://launcher.hytale.com/version/release/launcher.json"
MAX_AGE=86400

mkdir -p "$GAMEDIR"

installed_version() {
  if [ -f "$METADATA" ]; then
    jq -er '.version // empty' "$METADATA" 2>/dev/null || true
  fi
}

metadata_fresh() {
  [ -f "$METADATA" ] || return 1
  local now mtime
  now=$(date +%s)
  mtime=$(stat -c %Y "$METADATA" 2>/dev/null || echo 0)
  [ $((now - mtime)) -lt "$MAX_AGE" ]
}

fetch_latest() {
  curl -fsSL "$API" |
    jq -er '
      .version as $v
      | .download_url.linux.amd64 as $d
      | [$v, $d.url, $d.sha256]
      | @tsv
    '
}

INSTALLED_VER="$(installed_version || true)"

LATEST_VER=""
LATEST_URL=""
LATEST_HASH=""

if metadata_fresh && [ -n "$INSTALLED_VER" ]; then
  LATEST_VER="$INSTALLED_VER"
else
  if DATA="$(fetch_latest)"; then
    read -r LATEST_VER LATEST_URL LATEST_HASH <<<"$DATA"
  else
    if [ -x "$BIN" ]; then
      exec "$BIN" "$@"
    fi
    echo "Hytale launcher: failed to fetch metadata and no local binary available" >&2
    exit 1
  fi
fi

if [ -n "$LATEST_URL" ] && [ "$LATEST_VER" != "$INSTALLED_VER" ]; then
  TMP_ZIP="$(mktemp --suffix=.zip)"
  TMP_DIR="$(mktemp -d)"

  cleanup() {
    rm -f "$TMP_ZIP"
    rm -rf "$TMP_DIR"
  }
  trap cleanup EXIT

  curl -fL "$LATEST_URL" -o "$TMP_ZIP"
  echo "$LATEST_HASH  $TMP_ZIP" | sha256sum -c -

  unzip -oq "$TMP_ZIP" -d "$TMP_DIR"

  if [ ! -x "$TMP_DIR/hytale-launcher" ]; then
    echo "Hytale launcher: downloaded archive is missing executable" >&2
    exit 1
  fi

  mv -f "$TMP_DIR/hytale-launcher" "$BIN"
  chmod +x "$BIN"

  jq -n --arg v "$LATEST_VER" '{version:$v}' >"$METADATA"
fi

exec "$BIN" "$@"
