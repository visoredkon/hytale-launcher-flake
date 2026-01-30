{ pkgs }:

let
  pname = "hytale-launcher";
  version = "2026.01.29-a86a538";

  app = rec {
    inherit pname version;
    name = pname;
    description = "Official Hytale Game Launcher";
    homepage = "https://hytale.com";
    desktopName = "Hytale Launcher";
    desktopFileName = "${pname}.desktop";
    iconName = "hytale";
    startupWMClass = "com.hypixel.HytaleLauncher";
    categories = [ "Game" ];
    baseUrl = "https://launcher.hytale.com/builds/release/linux/amd64";
    url = "${baseUrl}/${pname}-${version}.zip";
    sha256 = "sha256-WaFwIUOf4W8D8M7ZWzuwFCnHHdGtOI8Sx6BI1rXrL0k=";
    iconUrl = "https://hytale.com/favicon.ico";
    iconSha256 = "eniMb/wct+vjtzXF2z8Z1XPBmwabjV8RCDyd8J1QLT0=";
  };

  launcherZip = pkgs.fetchurl {
    inherit (app) url sha256;
  };

  launcherBin = pkgs.stdenv.mkDerivation {
    pname = app.pname;
    inherit (app) version;

    src = launcherZip;
    nativeBuildInputs = [ pkgs.unzip ];

    unpackPhase = ''
      unzip $src
    '';

    installPhase = ''
      mkdir -p $out/bin
      install -m755 ${app.pname} $out/bin/${app.pname}
    '';
  };

  hytaleIcon = pkgs.fetchurl {
    url = app.iconUrl;
    sha256 = app.iconSha256;
  };

  desktopItem = pkgs.makeDesktopItem {
    name = app.pname;
    desktopName = app.desktopName;
    comment = app.description;
    exec = app.pname;
    icon = app.iconName;
    categories = app.categories;
    startupWMClass = app.startupWMClass;
  };

  iconPackage = pkgs.stdenv.mkDerivation {
    pname = "${app.pname}-icon";
    inherit (app) version;

    src = hytaleIcon;
    nativeBuildInputs = [ pkgs.imagemagick ];
    dontUnpack = true;

    installPhase =
      let
        sizes = [
          16
          32
          48
          64
          128
          256
        ];
        iconName = app.iconName;
      in
      ''
        ${pkgs.lib.concatMapStringsSep "\n" (size: ''
          dir=$out/share/icons/hicolor/${toString size}x${toString size}/apps
          mkdir -p "$dir"
          magick "$src" -resize ${toString size}x${toString size} "$dir/${iconName}.png"
        '') sizes}
      '';
  };

  meta = with pkgs.lib; {
    inherit (app) description homepage;
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = app.pname;
    inherit (app) desktopFileName;
  };

  fhs = pkgs.buildFHSEnv {
    name = app.pname;
    inherit meta;

    targetPkgs =
      pkgs: with pkgs; [
        glib
        gtk3
        gdk-pixbuf
        libsoup_3
        webkitgtk_4_1

        alsa-lib
        icu
        openssl
        libGL
        libxkbcommon
        wayland
      ];

    runScript = "${launcherBin}/bin/${app.pname}";
  };
in
pkgs.symlinkJoin {
  name = app.pname;

  paths = [
    fhs
    desktopItem
    iconPackage
  ];

  passthru = {
    inherit meta;
  };
}
