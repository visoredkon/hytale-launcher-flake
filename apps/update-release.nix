{ pkgs }:

pkgs.writeShellApplication {
  name = "hytale-launcher-update-release";
  runtimeInputs = with pkgs; [
    coreutils
    curl
    gawk
    git
    gnused
    jq
    nix
  ];
  text = ''
    set -euo pipefail

    COMMIT=false
    PUSH=false

    usage() {
      cat <<EOF
    Usage: ./update-release [OPTIONS] [DIR]

    OPTIONS:
      --commit       Commit updated release.nix and flake.lock
      --push         Push after committing (implies --commit)
      -h, --help     Show this help message
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
    releaseFile="$root/release.nix"
    API_URL="https://launcher.hytale.com/version/release/launcher.json"

    echo "==> Fetching latest release info..." >&2
    api_data=$(curl -fsSL "$API_URL")
    version=$(jq -er '.version' <<< "$api_data")
    zip_url=$(jq -er '.download_url.linux.amd64.url' <<< "$api_data")

    current_version="$(sed -n 's/^[[:space:]]*version = "\([^"]*\)";$/\1/p' "$releaseFile" | head -n1 || true)"

    has_changes=false
    if [ -n "$(git -C "$root" status --porcelain release.nix flake.lock 2>/dev/null)" ]; then
      has_changes=true
    fi

    if [[ "$current_version" == "$version" ]]; then
      if [[ "$has_changes" == "true" && "$COMMIT" == "true" ]]; then
        echo "==> Committing existing changes for version $version..." >&2
        git -C "$root" add release.nix flake.lock
        git -C "$root" commit -m "chore(launcher): bump version to $version"
        if [[ "$PUSH" == "true" ]]; then
          echo "==> Pushing changes..." >&2
          git -C "$root" push
        fi
        exit 0
      fi
      echo "==> Already up to date (version $version)" >&2
      exit 0
    fi

    echo "==> Updating from $current_version to $version..." >&2
    flatpak_url="''${zip_url%.zip}.flatpak"
    nix_hash=$(nix-prefetch-url --type sha256 "$flatpak_url" | tail -n1)
    sri_hash=$(nix --extra-experimental-features "nix-command" hash convert --to sri --hash-algo sha256 "$nix_hash")

    cat > "$releaseFile" <<EOF
    {
      sha256 = "$sri_hash";
      version = "$version";
    }
    EOF

    echo "==> Formatting files..." >&2
    nix --extra-experimental-features "nix-command flakes" fmt 2>/dev/null || true

    echo "==> Updating flake.lock..." >&2
    nix --extra-experimental-features "nix-command flakes" flake update 2>/dev/null || true

    if [[ "$COMMIT" == "true" ]]; then
      echo "==> Committing changes..." >&2
      git -C "$root" add .
      git -C "$root" commit -m "chore(launcher): bump version to $version"
      if [[ "$PUSH" == "true" ]]; then
        echo "==> Pushing changes..." >&2
        git -C "$root" push
      fi
    fi

    echo "==> Successfully updated to version $version" >&2
  '';
}
