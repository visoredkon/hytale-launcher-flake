{ pkgs }:

let
  release = import ./release.nix;

  app = rec {
    appId = "com.hypixel.HytaleLauncher";
    baseUrl = "https://launcher.hytale.com/builds/release/linux/amd64";
    description = "Official launcher for Hytale";
    desktopFileName = "${appId}.desktop";
    execName = "hytale-launcher";
    flatpakUrl = "${baseUrl}/${pname}-${version}.flatpak";
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

    # Version information obtained from the official Hytale API endpoint:
    # https://launcher.hytale.com/version/release/launcher.json
    #
    # The API provides download URLs in .zip format, but Flatpak packages are
    # available at the same location by replacing .zip with .flatpak extension.
    # This undocumented feature allows direct access to Flatpak builds without
    # additional conversion steps.
    inherit (release) sha256 version;
  };

  flatpakSrc = pkgs.fetchurl {
    sha256 = app.sha256;
    url = app.flatpakUrl;
  };

  hytale-launcher-unwrapped = pkgs.stdenv.mkDerivation {
    pname = "${app.pname}-unwrapped";
    inherit (app) version;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/hytale-launcher
      install -m755 files/bin/hytale-launcher $out/lib/hytale-launcher/hytale-launcher

      install -Dm644 files/share/applications/${app.desktopFileName} \
        $out/share/applications/${app.desktopFileName}
      sed -i 's|^Exec=hytale-launcher-wrapper$|Exec=hytale-launcher|' \
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

    nativeBuildInputs = with pkgs; [
      ostree
    ];

    src = flatpakSrc;

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
  };

  meta = with pkgs.lib; {
    inherit (app) description homepage;
    license = licenses.unfree;
    mainProgram = app.execName;
    platforms = [ "x86_64-linux" ];
  };

  wrapperScript = pkgs.writeShellApplication {
    name = "hytale-launcher-wrapper";
    text = ''
      set -e

      BUNDLED_VERSION_FILE="''${XDG_DATA_HOME:-$HOME/.local/share}/Hytale/.bundled_version"
      CURRENT_VERSION="${app.version}"
      LAUNCHER_BIN="''${XDG_DATA_HOME:-$HOME/.local/share}/Hytale/hytale-launcher"
      LAUNCHER_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/Hytale"
      LAUNCHER_LOG="''${XDG_DATA_HOME:-$HOME/.local/share}/Hytale/launcher-wrapper.log"

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

      export DESKTOP_STARTUP_ID="${app.appId}"
      export GIO_EXTRA_MODULES="${pkgs.glib-networking}/lib/gio/modules"
      export GTK_THEME="adw-gtk3"
      export JAVA_HOME="${pkgs.temurin-bin-25}"
      export LD_LIBRARY_PATH="${pkgs.openssl.out}/lib:''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      export WEBKIT_DISABLE_COMPOSITING_MODE=1
      export WEBKIT_DISABLE_DMABUF_RENDERER=1
      export __NV_DISABLE_EXPLICIT_SYNC=1

      exec "$LAUNCHER_BIN" "$@"
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
        cairo
        dav1d
        dbus
        elfutils
        enchant_2
        expat
        flac
        fontconfig
        freetype
        fribidi
        gccNGPackages_15.libatomic
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
        libGL
        libX11
        libXau
        libXcomposite
        libXcursor
        libXdamage
        libXext
        libXfixes
        libXi
        libXinerama
        libXrandr
        libXrender
        libaom
        libappindicator-gtk3
        libavif
        libcap
        libdrm
        libepoxy
        libevdev
        libffi
        libgcrypt
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
        libxcb
        libxkbcommon
        libxml2
        libxshmfence
        libxslt
        mesa
        nettle
        nghttp2
        nss
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
        temurin-bin-25
        tinysparql
        udev
        util-linux
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
    hytale-launcher-unwrapped
  ];

  inherit meta;

  passthru = {
    unwrapped = hytale-launcher-unwrapped;
  };
}
