{ pkgs }:

pkgs.writeShellApplication {
  name = "hytale-launcher-update-release";
  runtimeInputs = with pkgs; [
    coreutils
    curl
    git
    gnused
    jq
    nix
    ostree
  ];
  text = ''
    set -euo pipefail

    COMMIT=false
    PUSH=false

    curl_retry() {
      curl --retry 5 --retry-delay 2 --retry-all-errors --connect-timeout 10 "$@"
    }

    fail() {
      echo "Error: assets: $1" >&2
      exit 1
    }

    usage() {
      cat <<'EOF'
    Usage: update-release [OPTIONS] [DIR]

    OPTIONS:
      --commit             Commit refreshed assets and flake.lock
      --push               Push after committing (implies --commit)
      -h, --help           Show this help message
    EOF
    }

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
        if [[ "$1" != -* ]]; then
          root="$1"
          shift
        else
          usage
          exit 1
        fi
        ;;
      esac
    done

    root="''${root:-$(pwd)}"
    cd "$root" || exit 1
    API_URL="https://launcher.hytale.com/version/release/launcher.json"

    git pull || echo "git pull failed, continuing anyway" >&2

    echo "" >&2
    echo "fetch launcher metadata from $API_URL" >&2
    api_data=$(curl_retry -fsSL "$API_URL" || true)

    if [[ -z "$api_data" ]]; then
      fail "failed to fetch launcher metadata"
    fi

    version=$(jq -r '.version // ""' <<<"$api_data" || true)
    zip_url=$(jq -r '.download_url.linux.amd64.url // ""' <<<"$api_data" || true)

    if [[ -z "$version" ]]; then
      fail "failed to determine version"
    fi

    if [[ -z "$zip_url" ]]; then
      fail "failed to determine download URL"
    fi

    flatpak_url="''${zip_url%.zip}.flatpak"

    workdir=$(mktemp -d)
    trap 'rm -rf "$workdir"' EXIT

    echo "download $flatpak_url" >&2
    curl_retry -fsSL -o "$workdir/launcher.flatpak" "$flatpak_url" || fail "failed to download flatpak"

    (
      cd "$workdir"
      ostree --repo=repo init --mode=archive-z2
      ostree --repo=repo static-delta apply-offline launcher.flatpak

      commit="$(echo repo/objects/*/*.commit)"
      commit="''${commit#repo/objects/}"
      commit="''${commit%.commit}"
      commit="''${commit/\//}"

      ostree --repo=repo checkout -U "$commit" extracted
    )

    refreshed=false

    refresh_file() {
      local src="$1"
      local dest="$2"

      if [[ ! -f "$src" ]]; then
        fail "missing $src in flatpak"
      fi

      if [[ ! -f "$dest" ]] || ! cmp -s "$src" "$dest"; then
        install -Dm644 "$src" "$dest"
        echo "refreshed $dest" >&2
        refreshed=true
      fi
    }

    cp "$workdir/extracted/files/share/applications/com.hypixel.HytaleLauncher.desktop" "$workdir/launcher.desktop"
    sed -i 's|^Exec=hytale-launcher-wrapper$|Exec=hytale-launcher|' "$workdir/launcher.desktop"
    refresh_file "$workdir/launcher.desktop" "assets/com.hypixel.HytaleLauncher.desktop"
    refresh_file "$workdir/extracted/files/share/metainfo/com.hypixel.HytaleLauncher.metainfo.xml" "assets/com.hypixel.HytaleLauncher.metainfo.xml"

    for size in 32 48 64 128 256; do
      refresh_file "$workdir/extracted/files/share/icons/hicolor/''${size}x''${size}/apps/com.hypixel.HytaleLauncher.png" "assets/icons/''${size}.png"
    done

    rm -rf "$workdir"
    trap - EXIT

    if [[ "$refreshed" == "true" ]]; then
      echo "assets refreshed from flatpak $version" >&2
    else
      echo "assets already current for flatpak $version" >&2
    fi

    echo "" >&2
    echo "update flake.lock to latest inputs" >&2
    if ! nix flake update; then
      echo "Warning: flake update failed, continuing with existing flake.lock" >&2
    fi

    echo "" >&2
    echo "format" >&2
    if ! nix fmt; then
      echo "Warning: fmt failed, continuing with unformatted files" >&2
    fi

    echo "" >&2
    echo "lint checks" >&2
    nix build --no-link \
      ".#checks.x86_64-linux.embedded-lint" \
      ".#checks.x86_64-linux.format" \
      ".#checks.x86_64-linux.linter"

    echo "" >&2
    if [[ "$COMMIT" == "true" ]]; then
      echo "stage refreshed assets and flake.lock for commit" >&2
      git add apps assets flake.lock flake.nix package.nix

      if git diff --cached --quiet; then
        echo "nothing to commit" >&2
      else
        if [[ "$refreshed" == "true" ]]; then
          commit_subject="chore(assets): refresh from flatpak $version"
        else
          commit_subject="chore(deps): refresh flake inputs"
        fi

        commit_message_file=$(mktemp)

        {
          echo "$commit_subject"
          echo
          if [[ "$refreshed" == "true" ]]; then
            echo "flatpak version: $version"
          else
            echo "sync lockfile"
          fi
        } > "$commit_message_file"

        git commit -F "$commit_message_file"
        rm -f "$commit_message_file"

        if [[ "$PUSH" == "true" ]]; then
          echo "push to origin" >&2
          git push
        fi
      fi
    fi

    echo "" >&2
    echo "done" >&2
  '';
}
