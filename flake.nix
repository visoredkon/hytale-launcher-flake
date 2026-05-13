{
  description = "Unofficial Hytale Launcher Nix Flake for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      formatTargets = "apps/*.nix flake.nix package.nix release.nix";

      formatterApp = pkgs.callPackage ./apps/formatter.nix { inherit formatTargets; };

      hytale-launcher = pkgs.callPackage ./package.nix { };

      mkApp = program: {
        inherit program;
        type = "app";
      };

      pkgs = import nixpkgs {
        inherit system;
      };

      system = "x86_64-linux";

      update-release = pkgs.callPackage ./apps/update-release.nix { };
    in
    {
      apps.${system} = {
        default = mkApp "${hytale-launcher}/bin/hytale-launcher";
        update-release = mkApp "${update-release}/bin/hytale-launcher-update-release";
      };

      checks.${system}.format =
        pkgs.runCommand "check-format"
          {
            nativeBuildInputs = [ pkgs.nixfmt ];
            src = self;
          }
          ''
            cd $src
            nixfmt --check ${formatTargets}
            touch $out
          '';

      formatter.${system} = formatterApp;

      overlays.default = _: prev: {
        hytale-launcher = prev.callPackage ./package.nix { };
      };

      packages.${system} = {
        default = hytale-launcher;
        inherit hytale-launcher;
      };
    };
}
