{ pkgs }:

let
  app = rec {
    pname = "hytale-launcher";
    description = "Official launcher for Hytale";
    homepage = "https://hytale.com";

    appId = "com.hypixel.HytaleLauncher";
    desktopFileName = "${appId}.desktop";
    metainfoFileName = "${appId}.metainfo.xml";
    iconName = appId;

    execName = "hytale-launcher";

    iconSizes = [
      32
      48
      64
      128
      256
    ];

    # Version information obtained from the official Hytale API endpoint:
    # https://launcher.hytale.com/version/release/launcher.json
    #
    # The API provides download URLs in .zip format, but Flatpak packages are
    # available at the same location by replacing .zip with .flatpak extension.
    # This undocumented feature allows direct access to Flatpak builds without
    # additional conversion steps.
    #
    # Auto-updated by update-version.sh
    version = "2026.02.26-8739a13";
    sha256 = "sha256-4C+dbk0S8kYygUIPDUSJu7CQLxVAnkTEa/0FY4fFAE8=";
    # End of auto-updated section

    baseUrl = "https://launcher.hytale.com/builds/release/linux/amd64";
    flatpakUrl = "${baseUrl}/${pname}-${version}.flatpak";
  };

  flatpakSrc = pkgs.fetchurl {
    url = app.flatpakUrl;
    sha256 = app.sha256;
  };

  hytale-launcher-unwrapped = pkgs.stdenv.mkDerivation {
    pname = "${app.pname}-unwrapped";
    inherit (app) version;

    src = flatpakSrc;
    nativeBuildInputs = with pkgs; [
      ostree
    ];

    unpackPhase = ''
      runHook preUnpack

      ostree --repo=repo init --mode=archive-z2
      ostree --repo=repo static-delta apply-offline $src

      commit="$(echo repo/objects/*/*.commit)"
      commit="''${commit#repo/objects/}"
      commit="''${commit%.commit}"
      commit="''${commit/\//}"

      ostree --repo=repo checkout -U "$commit" extracted
      cp -a extracted/. .
      rm -rf repo extracted

      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/hytale-launcher
      install -m755 files/bin/hytale-launcher $out/lib/hytale-launcher/hytale-launcher

      install -Dm644 files/share/applications/${app.desktopFileName} \
        $out/share/applications/${app.desktopFileName}

      install -Dm644 files/share/metainfo/${app.metainfoFileName} \
        $out/share/metainfo/${app.metainfoFileName}

      ${builtins.concatStringsSep "\n" (
        map (size: ''
          install -Dm644 \
            files/share/icons/hicolor/${toString size}x${toString size}/apps/${app.iconName}.png \
            $out/share/icons/hicolor/${toString size}x${toString size}/apps/${app.iconName}.png
        '') app.iconSizes
      )}

      runHook postInstall
    '';
  };

  meta = with pkgs.lib; {
    inherit (app) description homepage;
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = app.execName;
    inherit (app) desktopFileName;
  };

  wrapperScript = pkgs.writeShellScript "hytale-launcher-wrapper" ''
    set -e

    LAUNCHER_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/Hytale"
    LAUNCHER_BIN="$LAUNCHER_DIR/hytale-launcher"
    BUNDLED_VERSION_FILE="$LAUNCHER_DIR/.bundled_version"
    LAUNCHER_LOG="$LAUNCHER_DIR/launcher-wrapper.log"
    CURRENT_VERSION="${app.version}"

    log_error() {
      local msg="$1"
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $msg" >> "$LAUNCHER_LOG"
      echo "Error: $msg" >&2
      if command -v notify-send >/dev/null 2>&1; then
        notify-send -u critical "Hytale Launcher Error" "$msg"
      fi
      exit 1
    }

    mkdir -p "$LAUNCHER_DIR" || log_error "Failed to create launcher directory"

    BUNDLED_BIN="${hytale-launcher-unwrapped}/lib/hytale-launcher/hytale-launcher"

    NEEDS_UPDATE=false
    if [ ! -x "$LAUNCHER_BIN" ]; then
      NEEDS_UPDATE=true
    elif [ ! -f "$BUNDLED_VERSION_FILE" ]; then
      NEEDS_UPDATE=true
    elif [ "$(cat "$BUNDLED_VERSION_FILE")" != "$CURRENT_VERSION" ]; then
      NEEDS_UPDATE=true
    fi

    if [ "$NEEDS_UPDATE" = true ]; then
      install -m755 "$BUNDLED_BIN" "$LAUNCHER_BIN" || log_error "Failed to install launcher binary"
      echo "$CURRENT_VERSION" > "$BUNDLED_VERSION_FILE" || {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: Failed to save version file" >> "$LAUNCHER_LOG"
      }
    fi

    export GTK_THEME="adw-gtk3"
    export WEBKIT_DISABLE_COMPOSITING_MODE=1

    export GIO_EXTRA_MODULES="${pkgs.glib-networking}/lib/gio/modules"
    export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    export LD_LIBRARY_PATH="${pkgs.openssl.out}/lib:''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

    exec "$LAUNCHER_BIN" "$@"
  '';

  fhs = pkgs.buildFHSEnv {
    name = app.execName;
    inherit meta;

    targetPkgs =
      pkgs: with pkgs; [
        hytale-launcher-unwrapped

        at-spi2-atk
        at-spi2-core
        atk
        cairo
        dbus
        expat
        gdk-pixbuf
        glib
        glib-networking
        gtk3
        hidapi
        json-glib
        libepoxy
        libevdev
        libgudev
        libsoup_3
        libxkbcommon
        pango
        pcre2
        tinysparql
        webkitgtk_4_1

        fontconfig
        freetype
        fribidi
        graphite2
        harfbuzz
        libdrm
        libglvnd
        libthai
        mesa
        pixman
        wayland
        xorg.libX11
        xorg.libXcomposite
        xorg.libXcursor
        xorg.libXdamage
        xorg.libXext
        xorg.libXfixes
        xorg.libXi
        xorg.libXinerama
        xorg.libXrandr
        xorg.libXrender
        xorg.libXau

        brotli
        dav1d
        flac
        gst_all_1.gst-plugins-base
        gst_all_1.gstreamer
        lame
        libavif
        libjpeg
        libjxl
        libmpg123
        libogg
        libopus
        libpng
        libpulseaudio
        libsndfile
        libvorbis
        libwebp
        orc
        pipewire
        sdl3
        woff2

        bzip2
        elfutils
        enchant_2
        gccNGPackages_15.libatomic
        glibc
        gnutls
        hyphen
        icu
        krb5
        lcms2
        libaom
        libappindicator-gtk3
        libcap
        libffi
        libgcrypt
        libGL
        libgpg-error
        libidn2
        libmanette
        libnotify
        libproxy
        libpsl
        libseccomp
        libsecret
        libtasn1
        libunistring
        libunwind
        libxml2
        libxshmfence
        libxslt
        libxcb
        nettle
        nghttp2
        nss
        openssl
        p11-kit
        pulseaudio
        sqlite
        stdenv.cc.cc.lib
        systemd
        util-linux
        xz
        zlib
        zstd
      ];

    runScript = wrapperScript;
  };
in
pkgs.symlinkJoin {
  name = app.pname;

  paths = [
    fhs
    hytale-launcher-unwrapped
  ];

  passthru = {
    inherit meta;
    unwrapped = hytale-launcher-unwrapped;
  };
}
