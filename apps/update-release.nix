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

    curl_retry() {
      curl --retry 5 --retry-delay 2 --retry-all-errors --connect-timeout 10 "$@"
    }

    release_field_value() {
      local release_file="$1"
      local field="$2"

      gawk -v field="$field" '
        match($0, field "[[:space:]]*=[[:space:]]*\"([^\"]*)\"", groups) {
          print groups[1]
          exit
        }
      ' "$release_file" 2>/dev/null || true
    }

    display_version() {
      if [[ -n "$1" ]]; then
        echo "$1"
      else
        echo "unknown"
      fi
    }

    fail() {
      echo "Error: launcher: $1" >&2
      exit 1
    }

    parse_update() {
      IFS=':' read -r pkg from_version to_version <<<"$1"
    }

    usage() {
      cat <<'EOF'
    Usage: update-release [OPTIONS] [DIR]

    OPTIONS:
      --commit             Commit updated release.nix and flake.lock
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
    releaseFile="release.nix"
    API_URL="https://launcher.hytale.com/version/release/launcher.json"

    git pull || echo "git pull failed, continuing anyway" >&2

    echo "check launcher from $API_URL" >&2
    api_data=$(curl_retry -fsSL "$API_URL" 2>/dev/null || true)

    if [[ -z "$api_data" ]]; then
      fail "failed to fetch launcher metadata"
    fi

    version=$(jq -r '.version // ""' <<<"$api_data")
    zip_url=$(jq -r '.download_url.linux.amd64.url // ""' <<<"$api_data")

    if [[ -z "$version" ]]; then
      fail "failed to determine version"
    fi

    if [[ -z "$zip_url" ]]; then
      fail "failed to determine download URL"
    fi

    current_version=$(release_field_value "$releaseFile" "version")

    updates=()

    if [[ "$current_version" != "$version" ]]; then
      echo "launcher: $(display_version "$current_version") -> $version" >&2
      flatpak_url="''${zip_url%.zip}.flatpak"
      sri_hash=$(nix --extra-experimental-features "nix-command" store prefetch-file --json "$flatpak_url" 2>/dev/null | jq -r '.hash // ""' || true)

      if [[ -z "$sri_hash" ]]; then
        fail "failed to determine sha256"
      fi

      cat > "$releaseFile" <<EOF
    {
      sha256 = "$sri_hash";
      version = "$version";
    }
    EOF

      echo "wrote $releaseFile" >&2

      updates+=("launcher:$(display_version "$current_version"):$version")
    else
      echo "already on $version" >&2
    fi

    echo "update flake.lock to latest inputs" >&2
    nix --extra-experimental-features "nix-command flakes" flake update 2>/dev/null || true

    echo "format" >&2
    nix --extra-experimental-features "nix-command flakes" fmt 2>/dev/null || true

    if [[ "$COMMIT" == "true" ]]; then
      echo "stage release.nix and flake.lock for commit" >&2
      git add release.nix flake.lock

      if git diff --cached --quiet; then
        echo "nothing to commit" >&2
      else
        update_count=''${#updates[@]}

        if [[ "$update_count" -eq 0 ]]; then
          commit_subject="chore(launcher): refresh release metadata"
        else
          parse_update "''${updates[0]}"
          commit_subject="chore(launcher): bump $pkg $from_version -> $to_version"
        fi

        commit_message_file=$(mktemp)

        {
          echo "$commit_subject"
          echo
          if [[ "$update_count" -eq 0 ]]; then
            echo "sync lockfile and release metadata"
          else
            echo "bumped:"
            for update in "''${updates[@]}"; do
              parse_update "$update"
              echo "- $pkg: $from_version -> $to_version"
            done
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

    if [[ "''${#updates[@]}" -gt 0 ]]; then
      echo "now on $version" >&2
    else
      echo "done, no version change" >&2
    fi
  '';
}
