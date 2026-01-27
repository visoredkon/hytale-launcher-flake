{ pkgs }:

let
  hytaleIcon = pkgs.fetchurl {
    url = "https://hytale.com/favicon.ico";
    sha256 = "eniMb/wct+vjtzXF2z8Z1XPBmwabjV8RCDyd8J1QLT0=";
  };

  desktopItem = pkgs.makeDesktopItem {
    name = "hytale-launcher";
    desktopName = "Hytale Launcher";
    comment = "Official Hytale Game Launcher";
    exec = "hytale-launcher";
    icon = "hytale";
    categories = [ "Game" ];
    startupWMClass = "com.hypixel.HytaleLauncher";
  };

  fhs = pkgs.buildFHSEnv {
    name = "hytale-launcher";

    meta = {
      description = "Hytale Launcher";
      homepage = "https://hytale.com";
      platforms = [ "x86_64-linux" ];
      mainProgram = "hytale-launcher";
    };

    targetPkgs =
      pkgs: with pkgs; [
        # Launcher's Deps
        glib
        gtk3
        gdk-pixbuf
        libsoup_3
        webkitgtk_4_1

        # Game's Deps
        alsa-lib
        icu
        openssl
        libGL
        libxkbcommon
        wayland

        # Script's Deps
        bash
        coreutils
        curl
        jq
        unzip
      ];

    runScript = pkgs.writeShellScript "hytale-launcher" (builtins.readFile ./hytale-launcher.sh);
  };
in
pkgs.symlinkJoin {
  name = "hytale-launcher";

  paths = [
    fhs
    desktopItem

    (pkgs.runCommand "hytale-icon" { } ''
      mkdir -p $out/share/icons/hicolor/256x256/apps
      cp ${hytaleIcon} \
         $out/share/icons/hicolor/256x256/apps/hytale.ico
    '')
  ];
}
