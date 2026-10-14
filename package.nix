{ pkgs }:

let
  app = rec {
    apiUrl = "https://launcher.hytale.com/version/release/launcher.json";
    appId = "com.hypixel.HytaleLauncher";
    description = "Official launcher for Hytale";
    desktopFileName = "${appId}.desktop";
    execName = "hytale-launcher";
    homepage = "https://hytale.com";
    iconName = appId;
    iconSizes = [
      32
      48
      64
      128
      256
    ];
    metainfoFileName = "${appId}.metainfo.xml";
    pname = "hytale-launcher";
  };

  assets = pkgs.stdenv.mkDerivation {
    name = "${app.pname}-assets";

    installPhase = ''
      runHook preInstall

      install -Dm644 $src/${app.desktopFileName} \
        $out/share/applications/${app.desktopFileName}

      install -Dm644 $src/${app.metainfoFileName} \
        $out/share/metainfo/${app.metainfoFileName}

      ${builtins.concatStringsSep "\n" (
        map (size: ''
          install -Dm644 \
            $src/icons/${toString size}.png \
            $out/share/icons/hicolor/${toString size}x${toString size}/apps/${app.iconName}.png
        '') app.iconSizes
      )}

      runHook postInstall
    '';

    src = ./assets;
  };

  meta = with pkgs.lib; {
    inherit (app) description homepage;
    license = licenses.unfree;
    mainProgram = app.execName;
    platforms = [ "x86_64-linux" ];
  };

  wrapperScript = pkgs.writeShellApplication {
    name = "hytale-launcher-wrapper";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      jq
      unzip
    ];
    text = ''
      set -euo pipefail

      API_URL="${app.apiUrl}"
      LAUNCHER_BIN="''${XDG_DATA_HOME:-$HOME/.local/share}/Hytale/hytale-launcher"
      LAUNCHER_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/Hytale"
      LAUNCHER_LOG="''${XDG_DATA_HOME:-$HOME/.local/share}/Hytale/launcher-wrapper.log"
      SAMEDEVICE_TMPDIR="$LAUNCHER_DIR/tmp"
      VERSION_FILE="''${XDG_DATA_HOME:-$HOME/.local/share}/Hytale/.launcher_version"

      curl_retry() {
        curl --retry 5 --retry-delay 2 --retry-all-errors --connect-timeout 10 "$@"
      }

      exec_launcher() {
        export GIO_EXTRA_MODULES="${pkgs.glib-networking}/lib/gio/modules"
        export LD_LIBRARY_PATH="${pkgs.openssl.out}/lib:''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        export WEBKIT_DISABLE_COMPOSITING_MODE=1
        export WEBKIT_DISABLE_DMABUF_RENDERER=1
        export __NV_DISABLE_EXPLICIT_SYNC=1

        exec "$LAUNCHER_BIN" "$@"
      }

      log_error() {
        local msg="$1"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $msg" >> "$LAUNCHER_LOG"
        echo "Error: $msg" >&2
        if command -v notify-send >/dev/null 2>&1; then
          notify-send -u critical "Hytale Launcher Error" "$msg"
        fi
        exit 1
      }

      log_warn() {
        local msg="$1"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $msg" >> "$LAUNCHER_LOG"
        echo "Warning: $msg" >&2
      }

      use_cached() {
        local msg="$1"
        shift
        log_warn "$msg"
        rm -rf "$workdir"
        trap - EXIT
        exec_launcher "$@"
      }

      mkdir -p "$SAMEDEVICE_TMPDIR" || log_error "Failed to create launcher directory"
      export TMPDIR="$SAMEDEVICE_TMPDIR"

      workdir=$(mktemp -d)
      trap 'rm -rf "$workdir"' EXIT

      api_data=$(curl_retry -fsSL "$API_URL" || true)

      if [[ -z "$api_data" ]]; then
        if [[ -x "$LAUNCHER_BIN" ]]; then
          use_cached "failed to fetch launcher metadata, using cached binary" "$@"
        fi
        log_error "failed to fetch launcher metadata"
      fi

      version=$(jq -r '.version // ""' <<<"$api_data" || true)
      want_sha=$(jq -r '.download_url.linux.amd64.sha256 // ""' <<<"$api_data" || true)
      zip_url=$(jq -r '.download_url.linux.amd64.url // ""' <<<"$api_data" || true)

      if [[ -z "$version" || -z "$want_sha" || -z "$zip_url" ]]; then
        if [[ -x "$LAUNCHER_BIN" ]]; then
          use_cached "incomplete launcher metadata, using cached binary" "$@"
        fi
        log_error "incomplete launcher metadata"
      fi

      have_version=""
      if [[ -f "$VERSION_FILE" ]]; then
        have_version=$(cat "$VERSION_FILE")
      fi

      if [[ ! -x "$LAUNCHER_BIN" || "$have_version" != "$version" ]]; then
        if ! curl_retry -fsSL -o "$workdir/launcher.zip" "$zip_url"; then
          if [[ -x "$LAUNCHER_BIN" ]]; then
            use_cached "download failed, using cached binary" "$@"
          fi
          log_error "failed to download launcher"
        fi

        if ! echo "$want_sha  $workdir/launcher.zip" | sha256sum -c -; then
          if [[ -x "$LAUNCHER_BIN" ]]; then
            use_cached "checksum mismatch, using cached binary" "$@"
          fi
          log_error "launcher checksum mismatch"
        fi

        if ! unzip -o -j "$workdir/launcher.zip" -d "$workdir"; then
          if [[ -x "$LAUNCHER_BIN" ]]; then
            use_cached "extract failed, using cached binary" "$@"
          fi
          log_error "failed to extract launcher"
        fi

        if [[ ! -f "$workdir/hytale-launcher" ]]; then
          if [[ -x "$LAUNCHER_BIN" ]]; then
            use_cached "launcher binary missing in archive, using cached binary" "$@"
          fi
          log_error "launcher binary missing in archive"
        fi

        install -m755 "$workdir/hytale-launcher" "$LAUNCHER_BIN" || log_error "Failed to install launcher binary"
        echo "$version" > "$VERSION_FILE" || log_error "Failed to save version file"

        rm -rf "$workdir"
        trap - EXIT
      fi

      exec_launcher "$@"
    '';
  };

  fhs = pkgs.buildFHSEnv {
    inherit meta;
    name = app.execName;

    runScript = "hytale-launcher-wrapper";

    targetPkgs =
      pkgs:
      (with pkgs; [
        alsa-lib
        at-spi2-atk
        at-spi2-core
        atk
        brotli
        bzip2
        cacert
        cairo
        dav1d
        dbus
        egl-wayland
        elfutils
        enchant_2
        expat
        flac
        fontconfig
        freetype
        fribidi
        gdk-pixbuf
        glib
        glib-networking
        glibc
        gnutls
        graphite2
        gst_all_1.gst-plugins-base
        gst_all_1.gstreamer
        gtk3
        harfbuzz
        hidapi
        hyphen
        icu
        json-glib
        krb5
        lame
        lcms2
        libaom
        libappindicator-gtk3
        libavif
        libcap
        libdecor
        libdrm
        libepoxy
        libevdev
        libffi
        libgcrypt
        libGL
        libGLU
        libglvnd
        libgpg-error
        libgudev
        libidn2
        libjpeg
        libjxl
        libmanette
        libmpg123
        libnotify
        libogg
        libopus
        libpng
        libproxy
        libpsl
        libpulseaudio
        libseccomp
        libsecret
        libsndfile
        libsoup_3
        libtasn1
        libthai
        libunistring
        libunwind
        libvorbis
        libwebp
        libX11
        libXau
        libxcb
        libXcomposite
        libXcursor
        libXdamage
        libXext
        libXfixes
        libXi
        libXinerama
        libxkbcommon
        libxml2
        libXrandr
        libXrender
        libxscrnsaver
        libxshmfence
        libxslt
        libxxf86vm
        mesa
        nettle
        nghttp2
        nspr
        nss
        numactl
        openssl
        orc
        p11-kit
        pango
        pcre2
        pipewire
        pixman
        pulseaudio
        sdl3
        sqlite
        stdenv.cc.cc.lib
        systemd
        tinysparql
        udev
        util-linux
        vulkan-loader
        wayland
        webkitgtk_4_1
        woff2
        xdg-utils
        xz
        zlib
        zstd
      ])
      ++ [
        wrapperScript
      ];
  };
in
pkgs.symlinkJoin {
  name = app.pname;

  paths = [
    fhs
    assets
  ];

  inherit meta;
}
