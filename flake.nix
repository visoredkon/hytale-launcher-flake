{
  description = "Unofficial Hytale Launcher Nix Flake for NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
      };
      package = import ./wrapper.nix { inherit pkgs; };
    in
    {
      packages.${system}.default = package;

      apps.${system}.default = {
        type = "app";
        program = "${package}/bin/hytale-launcher";
      };
    };
}
