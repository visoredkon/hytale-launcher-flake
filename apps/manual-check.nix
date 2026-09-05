{ hytale-launcher, pkgs }:
let
  checkPython = pkgs.writeText "hytale-manual-check.py" ''
    import pathlib
    import re
    import sys
    from collections import Counter

    log_path = pathlib.Path(sys.argv[1])

    if not log_path.exists():
        print(f"Log not found: {log_path}", file=sys.stderr)
        sys.exit(1)

    text: str = log_path.read_text(errors="ignore")

    enoent: set[str] = set()
    success: set[str] = set()
    enoent_counter: Counter[str] = Counter()
    success_counter: Counter[str] = Counter()

    for line in text.splitlines():
        if "openat" not in line or ".so" not in line:
            continue

        m = re.search(r'"([^"]*\.so[^"]*)"', line)
        if not m:
            continue

        raw = m.group(1)
        name = raw.split("/")[-1]
        base = re.sub(r"\.so.*", ".so", name)

        if "ENOENT" in line:
            enoent.add(base)
            enoent_counter[base] += 1
        elif re.search(r"= \d+$", line):
            success.add(base)
            success_counter[base] += 1

    only_enoent: set[str] = enoent - success

    fallback_pairs: dict[str, str] = {
        "discord_partner_sdk.so": "libdiscord_partner_sdk.so",
        "Noesis.so": "libNoesis.so",
        "openal.so": "libopenal.so",
        "quiche.so": "libquiche.so",
        "SDL3.so": "libSDL3.so",
        "SDL3_image.so": "libSDL3_image.so",
        "vorbisfile.so": "libvorbisfile.so",
        "wuffs.so": "libwuffs.so",
        "zstd.so": "libzstd.so",
    }

    real_missing: set[str] = set()
    for lib in only_enoent:
        fallback = fallback_pairs.get(lib)
        if fallback and fallback in success:
            continue
        real_missing.add(lib)

    print()
    print("=== Hytale Manual Trace Report ===")
    print(f"Log: {log_path}")
    print(f"Total openat .so attempts: {len(enoent) + len(success)} unique libs")
    print(f"  ENOENT unique: {len(enoent)}")
    print(f"  Success unique: {len(success)}")
    print(f"  Only ENOENT (never succeeded): {len(only_enoent)}")
    print(f"  Real missing after fallback filter: {len(real_missing)}")
    print()

    if real_missing:
        print("Missing primary libs (no fallback succeeded):")
        for lib in sorted(real_missing):
            print(f"  - {lib} ({enoent_counter[lib]} attempts)")
        print()
        print("Recommendation: add Nixpkgs package to targetPkgs")
        print("  libdecor-0.so -> libdecor, libnuma.so -> numactl")
        print()
    else:
        print("No missing primary libs, all ENOENT had fallback success")
        print()

    exec_checks = {
        "HytaleClient": "HytaleClient" in text,
        "java": "libjvm.so" in text,
        "xdg-open": text.count("execve") and "xdg-open" in text,
    }

    print("Execve checks:")
    for name, found in exec_checks.items():
        status = "FOUND" if found else "NOT FOUND"
        print(f"  {name}: {status}")

    if "xdg-open" in text:
        xdg_count = text.count("xdg-open")
        print(f"  xdg-open execve count: {xdg_count}")

    print()
    print("Top success libs:")
    for lib, cnt in success_counter.most_common(10):
        print(f"  {lib}: {cnt}")

    print()
    print(f"Full log: {log_path}")
    print("Latest symlink: /tmp/hytale-trace-latest.log")
  '';
in
pkgs.writeShellApplication {
  name = "hytale-launcher-manual-check";

  runtimeInputs = with pkgs; [
    coreutils
    gawk
    gnugrep
    gnused
    procps
    python3
    strace
  ];

  text = ''
    set -euo pipefail

    default_launcher="${hytale-launcher}/bin/hytale-launcher"
    default_log_dir="/tmp"
    default_log_file=""

    launcher_path="$default_launcher"
    log_dir="$default_log_dir"
    log_file="$default_log_file"

    print_usage() {
      cat <<EOF
    Usage: hytale-launcher-manual-check [OPTIONS]

    Run the Hytale Launcher with full system tracing. Play as usual,
    then close the launcher to generate a dependency report.

    OPTIONS:
      --launcher PATH        Launcher binary (default: $default_launcher)
      --log-dir DIR          Directory for trace logs (default: $default_log_dir)
      --log-file FILE        Exact log file (overrides --log-dir)
      -h, --help             Show this help message
    EOF
    }

    while [[ $# -gt 0 ]]; do
      case "$1" in
      --launcher)
        launcher_path="$2"
        shift 2
        ;;
      --log-dir)
        log_dir="$2"
        shift 2
        ;;
      --log-file)
        log_file="$2"
        shift 2
        ;;
      -h | --help)
        print_usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        print_usage >&2
        exit 1
        ;;
      esac
    done

    if [[ ! -x "$launcher_path" ]]; then
      echo "Launcher not executable: $launcher_path" >&2
      exit 1
    fi

    if [[ -z "$log_file" ]]; then
      timestamp="$(date +%Y%m%d-%H%M%S)"
      mkdir -p "$log_dir"
      log_file="$log_dir/trace-$timestamp.log"
    else
      mkdir -p "$(dirname "$log_file")"
    fi

    latest_link="/tmp/hytale-trace-latest.log"
    tmp_link="/tmp/hytale-manual-latest.log"

    echo "==> Launcher: $launcher_path" >&2
    echo "==> Trace log: $log_file" >&2
    echo "==> Latest symlink: $latest_link" >&2
    echo "==> Temporary symlink: $tmp_link" >&2
    echo "==> Launcher tracing started, play as usual." >&2
    echo "==> When finished, close the launcher window or press Ctrl+C to generate the report." >&2
    echo "" >&2

    mkdir -p "$(dirname "$latest_link")"
    ln -sf "$log_file" "$latest_link"
    ln -sf "$log_file" "$tmp_link"

    trap 'echo ""; echo "==> Interrupted, analysing trace..." >&2' INT TERM

    if ! strace -f -tt -e openat,openat2,execve -o "$log_file" "$launcher_path"; then
      status=$?
      if [[ $status -ne 0 && $status -ne 130 ]]; then
        echo "Launcher exited with status $status" >&2
      fi
    fi

    echo "" >&2
    echo "==> Trace complete: $log_file ($(wc -l < "$log_file") lines, $(du -h "$log_file" | cut -f1))" >&2
    echo "==> Analysing..." >&2

    python3 ${checkPython} "$log_file" >&2

    echo "" >&2
    echo "==> Report complete" >&2
    echo "==> Log retained at: $log_file" >&2
  '';
}
