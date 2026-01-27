{
  description = "Unofficial Hytale Launcher Nix Flake for NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
      };
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
        default = hytale-launcher;
      };

      apps.${system}.default = {
        type = "app";
        program = "${hytale-launcher}/bin/hytale-launcher";
        meta = hytale-launcher.meta;
      };

      formatter.${system} = pkgs.writeShellScriptBin "format-all" ''
        ${pkgs.nixfmt}/bin/nixfmt ${toString nixFiles}
        ${pkgs.shfmt}/bin/shfmt -w ${shfmtOpts} ${toString shellScripts}
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
              nixfmt --check flake.nix wrapper.nix
              shfmt -d ${shfmtOpts} update-version.sh
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
