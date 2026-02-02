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
  printf '==> %s\n' "$*" >&2
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
  info "Fetching latest version from API..."

  local api_data
  if ! api_data=$(curl -fsSL "$API_URL" 2>&1); then
    die "Failed to fetch API data: $api_data"
  fi

  local version zip_url
  if ! version=$(jq -er '.version' <<< "$api_data" 2>&1); then
    die "Missing version in API response: $version"
  fi
  if ! zip_url=$(jq -er '.download_url.linux.amd64.url' <<< "$api_data" 2>&1); then
    die "Missing download URL in API response: $zip_url"
  fi

  info "Latest version: $version"

  local flatpak_url="${zip_url%.zip}.flatpak"
  info "Flatpak URL: $flatpak_url"

  local nix_hash sri_hash
  if ! nix_hash=$(nix-prefetch-url --type sha256 "$flatpak_url" 2>&1 | tail -n1); then
    die "Failed to fetch flatpak from $flatpak_url"
  fi

  if ! sri_hash=$(nix-hash --to-sri --type sha256 "$nix_hash" 2>&1); then
    die "Failed to convert hash to SRI format: $sri_hash"
  fi

  info "Computed hash (SRI): $sri_hash"

  printf '%s %s\n' "$version" "$sri_hash"
}

get_current_version() {
  grep -oP '^\s*version = "\K[^"]+' "$WRAPPER_FILE" | head -n1 || true
}

get_current_hash() {
  grep -oP '^\s*sha256 = "\K[^"]+' "$WRAPPER_FILE" | head -n1 || true
}

update_wrapper() {
  local version="$1" hash="$2"
  info "Updating $WRAPPER_FILE..."

  local tmp
  tmp=$(mktemp)

  awk -v version="$version" -v hash="$hash" '
    /^[[:space:]]*version = ".*";$/ && !seen_version {
      print "  version = \"" version "\";"
      seen_version = 1
      next
    }
    /^[[:space:]]*sha256 = "sha256-.*";$/ && !seen_hash {
      print "    sha256 = \"" hash "\";"
      seen_hash = 1
      next
    }
    { print }
  ' "$WRAPPER_FILE" > "$tmp"

  if ! grep -q "version = \"$version\"" "$tmp"; then
    rm -f "$tmp"
    die "Failed to update version in $WRAPPER_FILE"
  fi
  if ! grep -q "sha256 = \"$hash\"" "$tmp"; then
    rm -f "$tmp"
    die "Failed to update hash in $WRAPPER_FILE"
  fi

  mv "$tmp" "$WRAPPER_FILE"
}

update_flake_lock() {
  info "Updating flake.lock..."
  nix flake update --flake "$SCRIPT_DIR"
}

format_files() {
  info "Formatting files..."
  nix fmt || die "Failed to format files"
}

commit_changes() {
  local version="$1"
  info "Committing changes..."

  git add "$WRAPPER_FILE" "$LOCK_FILE" || die "Failed to stage changes"
  git commit -m "chore(launcher): bump version to $version" || die "Failed to commit changes"

  if [[ "$PUSH" == "true" ]]; then
    info "Pushing changes..."
    git push || die "Failed to push changes"
  fi
}

main() {
  local version_info
  if ! version_info=$(fetch_version_info); then
    exit 1
  fi

  read -r VERSION SRI_HASH <<< "$version_info"

  local current_version current_hash
  current_version=$(get_current_version)
  current_hash=$(get_current_hash)

  local has_changes=false
  if ! git diff --quiet "$WRAPPER_FILE" "$LOCK_FILE" 2> /dev/null; then
    has_changes=true
  fi

  if [[ "$current_version" == "$VERSION" && "$current_hash" == "$SRI_HASH" ]]; then
    if [[ "$has_changes" == "true" && "$COMMIT" == "true" ]]; then
      info "Version already up to date, committing existing changes..."
      commit_changes "$VERSION"
      info "Successfully committed version $VERSION"
      exit 0
    fi

    info "Already up to date (version $VERSION)"
    exit 0
  fi

  info "Updating from $current_version to $VERSION"
  update_wrapper "$VERSION" "$SRI_HASH"
  format_files
  update_flake_lock

  if [[ "$COMMIT" == "true" ]]; then
    commit_changes "$VERSION"
  fi

  info "Successfully updated to version $VERSION"
}

main
