# Unofficial Hytale Launcher for NixOS

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![NixOS](https://img.shields.io/badge/NixOS-Unstable-blue.svg)](https://nixos.org)

Run the official Hytale Launcher on NixOS through a compatibility wrapper.

> ⚠️ **Disclaimer**<br/>
> Not affiliated with, endorsed by, or associated with Hypixel Studios Canada Inc. This is an unofficial community-maintained compatibility wrapper.

---

## Overview

Most Linux applications expect a traditional Filesystem Hierarchy Standard (FHS) environment, which NixOS does not provide. This flake creates an FHS-compatible sandbox that runs the official Hytale Launcher without modifications.

**What this provides:**
- FHS-compatible runtime environment
- Proper binary installation and version tracking
- Required system libraries (GTK, WebKit, graphics, audio)

**What this does NOT do:**
- Bypass authentication, DRM, or security systems
- Circumvent technical protections or anti-cheat systems
- Enable offline play, cracks, or unauthorized access
- Modify, decompile, or reverse engineer the launcher binary
- Provide mods, cheats, exploits, or unauthorized tools
- Redistribute the Hytale launcher or game binaries

---

## System Requirements

- **Platform**: `x86_64-linux`
- **Nix**: Flakes enabled
- **License**: Must allow unfree packages (launcher is proprietary)

---

## Quick Start

### Try Without Installing

```bash
NIXPKGS_ALLOW_UNFREE=1 nix run --impure github:visoredkon/hytale-launcher-flake
```

### Build Locally

```bash
NIXPKGS_ALLOW_UNFREE=1 nix build --impure github:visoredkon/hytale-launcher-flake
./result/bin/hytale-launcher
```

---

## Installation

### Allow Unfree Packages First

The launcher is proprietary software. Choose one method:

**Option 1: System-wide**
```nix
nixpkgs.config.allowUnfree = true;
```

**Option 2: Per-package (recommended)**
```nix
nixpkgs.config.allowUnfreePredicate = pkg:
  builtins.elem (lib.getName pkg) [ "hytale-launcher" ];
```

### NixOS Configuration

**flake.nix**
```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    hytale-launcher = {
      url = "github:visoredkon/hytale-launcher-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, ... }:
  let
    lib = nixpkgs.lib;

    nixpkgsConfig = {
      nixpkgs = {
        overlays = [ inputs.hytale-launcher.overlays.default ];
        config.allowUnfreePredicate = pkg:
          builtins.elem (lib.getName pkg) [ "hytale-launcher" ];
      };
    };
  in
  {
    nixosConfigurations.yourhost = lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        nixpkgsConfig
        ./configuration.nix
      ];
    };
  };
}
```

**configuration.nix**
```nix
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.hytale-launcher ];
}
```

### Home Manager

**flake.nix**
```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hytale-launcher = {
      url = "github:visoredkon/hytale-launcher-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, ... }:
  let
    lib = nixpkgs.lib;
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    nixpkgsConfig = {
      nixpkgs = {
        overlays = [ inputs.hytale-launcher.overlays.default ];
        config.allowUnfreePredicate = pkg:
          builtins.elem (lib.getName pkg) [ "hytale-launcher" ];
      };
    };
  in
  {
    homeConfigurations.youruser = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = { inherit inputs; };
      modules = [
        nixpkgsConfig
        ./home.nix
      ];
    };
  };
}
```

**home.nix**
```nix
{ pkgs, ... }:

{
  home.packages = [ pkgs.hytale-launcher ];
}
```

---

## Development

### Updates

No manual version bumps. The wrapper fetches the latest launcher from Hytale's API at runtime and caches it in `~/.local/share/Hytale`. It checks the SHA-256 from the API before installing. If the API is unreachable, the cached binary is used.

Refresh vendored assets and flake inputs:

```bash
nix run .#update-release              # Preview changes
nix run .#update-release -- --commit  # Commit changes
nix run .#update-release -- --push    # Commit and push
```

The script refreshes `assets/` from the latest Flatpak and then updates `flake.lock`. The refresh covers the desktop entry, metainfo, and icons.

### Available Commands

- `nix build` builds the package
- `nix fmt` formats Nix files
- `nix flake check` runs the format, linter, and shell/python lint checks
- `nix run .#update-release` refreshes assets and flake inputs

### Package Structure

```
./result/
├── bin/
│   └── hytale-launcher                  # FHS wrapper executable
└── share/
    ├── applications/
    │   └── com.hypixel.HytaleLauncher.desktop
    ├── metainfo/
    │   └── com.hypixel.HytaleLauncher.metainfo.xml
    └── icons/hicolor/
        ├── 32x32/apps/
        ├── 48x48/apps/
        ├── 64x64/apps/
        ├── 128x128/apps/
        └── 256x256/apps/
```

**Available outputs:**
- `packages.default` is the full FHS wrapper (recommended)
- `apps.default` is the runnable application
- `apps.update-release` refreshes vendored assets and flake inputs

---

## Troubleshooting

If you encounter issues, check the log file at:
```bash
~/.local/share/Hytale/launcher-wrapper.log
```

### Run on NVIDIA PRIME offload

The flake ships one desktop entry for all systems. If you use NVIDIA PRIME offload, add a second entry with Home Manager:

```nix
{
  xdg.desktopEntries.hytale-launcher-nvidia = {
    name = "Hytale Launcher (NVIDIA)";
    comment = "Official launcher for Hytale";
    exec = "nvidia-offload hytale-launcher";
    icon = "com.hypixel.HytaleLauncher";
    terminal = false;
    type = "Application";
    categories = [ "Game" ];
    settings = {
      Keywords = "hytale;game;launcher;hypixel;";
      StartupWMClass = "com.hypixel.HytaleLauncher";
    };
  };
}
```

This entry needs `hardware.nvidia.prime.offload.enable = true` on NixOS. The icon resolves from this flake, so nothing else changes.

---

## Technical Details

### Binary Source

The wrapper downloads the launcher binary at runtime from Hytale's official builds:
- **API Endpoint**: `https://launcher.hytale.com/version/release/launcher.json`
- **Distribution Format**: ZIP for `linux/amd64`
- **Verification**: SHA-256 from the API response, checked before install
- **Fallback**: cached binary in `~/.local/share/Hytale` when the API is unreachable

### Version Management

The wrapper maintains launcher state in `~/.local/share/Hytale`:
- **Binary**: `hytale-launcher` (downloaded, not from Nix store)
- **Version file**: `.launcher_version` (tracks downloaded version)
- **Log file**: `launcher-wrapper.log` (error diagnostics)

Binary updates trigger when:
- Binary doesn't exist or isn't executable
- Version file is missing
- Version differs from the API response

---

## Compliance & Legal

This wrapper is designed to respect Hytale's [Terms of Service](https://hytale.com/terms-of-service) and [EULA](https://hytale.com/eula):

| Aspect | Implementation |
|:-------|:---------------|
| **Authentication** | Handled entirely by official launcher. No credential interception. |
| **Distribution** | Only Nix code and desktop-integration assets (icon, `.desktop` entry, metainfo from the official Flatpak) are distributed. Launcher and game binaries are always downloaded from official sources, never hosted here. |
| **Launcher Binary** | Downloaded at runtime from `launcher.hytale.com`. SHA-256 from API verified before install. |
| **No Circumvention** | No bypassing of technical protections, DRM, or anti-cheat systems. |
| **No Modifications** | Binary runs unmodified in FHS sandbox. No decompilation, reverse engineering, or code injection. |

*Referenced: [Terms of Service v2.2](https://hytale.com/terms-of-service) & [EULA v2.3](https://hytale.com/eula) (Effective January 13, 2026)*

### License

**This Repository**: [MIT License](LICENSE). It covers only the Nix expressions and shell scripts.

**Hytale Launcher**: Proprietary software governed by [Hytale's EULA](https://hytale.com/eula).

### Trademarks

Hytale® and Hypixel Studios® are trademarks of Hypixel Studios Canada Inc. Used for identification purposes only.

### Disclaimer

This software is provided "as is", without warranty of any kind. Users must ensure their use complies with applicable terms and local laws.
