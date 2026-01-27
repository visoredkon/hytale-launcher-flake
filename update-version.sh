#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq nix

set -euo pipefail

readonly SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
readonly API_URL="https://launcher.hytale.com/version/release/launcher.json"
readonly WRAPPER_FILE="$SCRIPT_DIR/wrapper.nix"
readonly LOCK_FILE="$SCRIPT_DIR/flake.lock"

COMMIT=false
PUSH=false

cd "$SCRIPT_DIR"

usage() {
  cat << 'EOF'
Usage: ./update-version.sh [OPTIONS]

Update Hytale Launcher to the latest version from the official API.

OPTIONS:
  --commit       Commit updated wrapper.nix and flake.lock
  --push         Push after committing (implies --commit)
  -h, --help     Show this help message

EXAMPLES:
  ./update-version.sh              # Just update files
  ./update-version.sh --commit     # Update and commit
  ./update-version.sh --push       # Update, commit, and push
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

info() {
  printf '==> %s\n' "$*"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --commit)
        COMMIT=true
        shift
        ;;
      --push)
        PUSH=true
        COMMIT=true
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        usage
        die "Unknown option: $1"
        ;;
    esac
  done
}

parse_args "$@"

fetch_version_info() {
  info "Fetching latest version from Hytale API..." >&2

  local api_data
  api_data=$(curl -fsSL "$API_URL") || die "Failed to fetch API data"

  local version hex_hash
  version=$(jq -er '.version' <<< "$api_data") || die "Missing version in API response"
  hex_hash=$(jq -er '.download_url.linux.amd64.sha256' <<< "$api_data") || die "Missing checksum in API response"

  [[ -n "$version" && -n "$hex_hash" ]] || die "Invalid API response"

  info "Latest version: $version" >&2

  local sri_hash
  sri_hash=$(nix-hash --to-sri --type sha256 "$hex_hash")
  info "Converted hash to SRI format: $sri_hash" >&2

  echo "$version $sri_hash"
}

get_current_version() {
  grep -oP '^\s*version = "\K[^"]+' "$WRAPPER_FILE" | head -n1 || true
}

update_wrapper() {
  local version="$1" hash="$2"
  info "Updating $WRAPPER_FILE..." >&2

  local tmp
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' RETURN

  awk -v version="$version" -v hash="$hash" '
    /^[[:space:]]*version = "/ && !seen_version {
      print "  version = \"" version "\";"
      seen_version = 1
      next
    }
    /^[[:space:]]*sha256 = "sha256-/ && !seen_sha256 {
      print "    sha256 = \"" hash "\";"
      seen_sha256 = 1
      next
    }
    { print }
  ' "$WRAPPER_FILE" > "$tmp"

  mv "$tmp" "$WRAPPER_FILE"
  trap - RETURN
}

update_flake_lock() {
  info "Updating flake.lock..."
  nix flake update --flake "$SCRIPT_DIR"
}

commit_changes() {
  local version="$1"

  info "Committing changes..."
  git add "$WRAPPER_FILE" "$LOCK_FILE"
  git commit -m "chore(launcher): bump version to $version"

  if [[ "$PUSH" == "true" ]]; then
    info "Pushing changes..."
    git push
  fi
}

main() {
  read -r VERSION SRI_HASH <<< "$(fetch_version_info)"

  local current_version
  current_version=$(get_current_version)

  if [[ "$current_version" == "$VERSION" ]]; then
    info "Already up to date (version $VERSION)"
    exit 0
  fi

  update_wrapper "$VERSION" "$SRI_HASH"
  info "Successfully updated to version $VERSION"

  update_flake_lock

  if [[ "$COMMIT" == "true" ]]; then
    commit_changes "$VERSION"
  fi
}

main
