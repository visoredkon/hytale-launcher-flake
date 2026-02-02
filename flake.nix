{
  description = "Unofficial Hytale Launcher Nix Flake for NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      hytale-launcher = pkgs.callPackage ./wrapper.nix { };

      nixFiles = [
        ./flake.nix
        ./wrapper.nix
      ];
      shellScripts = [ ./update-version.sh ];
      shfmtOpts = "-i 2 -bn -ci -sr";
    in
    {
      packages.${system} = {
        inherit hytale-launcher;
        hytale-launcher-unwrapped = hytale-launcher.unwrapped;
        default = hytale-launcher;
      };

      apps.${system}.default = {
        type = "app";
        program = "${hytale-launcher}/bin/hytale-launcher";
        meta = hytale-launcher.meta;
      };

      formatter.${system} = pkgs.writeShellScriptBin "format-all" ''
        ${pkgs.nixfmt}/bin/nixfmt flake.nix wrapper.nix
        ${pkgs.shfmt}/bin/shfmt -w ${shfmtOpts} update-version.sh
      '';

      checks.${system} = {
        build = hytale-launcher;

        format =
          pkgs.runCommand "check-format"
            {
              nativeBuildInputs = with pkgs; [
                nixfmt
                shfmt
              ];
              src = self;
            }
            ''
              cd $src
              nixfmt --check ${toString nixFiles}
              shfmt -d ${shfmtOpts} ${toString shellScripts}
              touch $out
            '';
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          curl
          jq
          nil
          nixfmt
          shfmt
        ];

        shellHook = ''
          echo "Hytale Launcher development environment"
          echo "Commands:"
          echo "  nix build           - Build the package"
          echo "  nix fmt             - Format files"
          echo "  nix flake check     - Run checks"
          echo "  ./update-version.sh - Update launcher version"
        '';
      };

      overlays.default = final: prev: {
        hytale-launcher = prev.callPackage ./wrapper.nix { };
      };
    };
}
