# Unofficial Hytale Launcher for NixOS

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![NixOS](https://img.shields.io/badge/NixOS-Unstable-blue.svg)](https://nixos.org)

Run the **official Hytale Launcher** on NixOS through a compatibility wrapper.

> ⚠️ **Disclaimer**<br/>
> Not affiliated with, endorsed by, or associated with Hypixel Studios Canada Inc. This is an unofficial community-maintained compatibility wrapper.

---

## Overview

NixOS doesn't provide the traditional Filesystem Hierarchy Standard (FHS) environment that most Linux applications expect. This flake creates an FHS-compatible sandbox that allows the official Hytale Launcher to run without modifications.

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
- Redistribute Hytale binaries or game assets

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

### Update to Latest Version

Automated script to fetch the latest launcher from Hytale's API:

```bash
./update-version.sh              # Preview changes
./update-version.sh --commit     # Commit changes
./update-version.sh --push       # Commit and push
```

The script automatically:
- Fetches version and download URL from `https://launcher.hytale.com/version/release/launcher.json`
- Derives Flatpak URL from ZIP URL (replaces `.zip` with `.flatpak`)
- Downloads and computes SHA-256 hash of Flatpak package
- Updates `version` and `sha256` in [wrapper.nix](wrapper.nix)
- Formats files and updates [flake.lock](flake.lock)
- Creates conventional commit message (if `--commit` flag is used)

### Development Shell

```bash
nix develop
```

Available commands:
- `nix build` - Build the package
- `nix fmt` - Format Nix and shell files
- `nix flake check` - Run build and format validation checks
- `./update-version.sh` - Update launcher version

### Package Structure

```
./result/
├── bin/
│   └── hytale-launcher                  # FHS wrapper executable
├── lib/
│   └── hytale-launcher/
│       └── hytale-launcher              # Unwrapped binary
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
- `packages.default` - Full FHS wrapper (recommended)
- `packages.hytale-launcher-unwrapped` - Raw binary without FHS
- `apps.default` - Runnable application

---

## Troubleshooting

If you encounter issues, check the log file at:
```bash
~/.local/share/Hytale/launcher-wrapper.log
```

---

## Technical Details

### Binary Source

The launcher binary is obtained from Hytale's official Flatpak builds:
- **API Endpoint**: `https://launcher.hytale.com/version/release/launcher.json`
- **Distribution Format**: Flatpak (undocumented, derived from `.zip` URLs)
- **Extraction**: Using OSTree to unpack Flatpak archives
- **Verification**: SHA-256 checksums computed with `nix-prefetch-url`

### Version Management

The wrapper maintains launcher state in `~/.local/share/Hytale`:
- **Binary**: `hytale-launcher` (copied from Nix store)
- **Version file**: `.bundled_version` (tracks wrapper version)
- **Log file**: `launcher-wrapper.log` (error diagnostics)

Version updates trigger when:
- Binary doesn't exist or isn't executable
- Version file is missing
- Version mismatch between wrapper and binary

---

## Compliance & Legal

This wrapper is designed to respect Hytale's [Terms of Service](https://hytale.com/terms-of-service) and [EULA](https://hytale.com/eula):

| Aspect | Implementation |
|:-------|:---------------|
| **Authentication** | Handled entirely by official launcher. No credential interception. |
| **Distribution** | Only Nix code is distributed. Binaries downloaded directly from official sources. |
| **Launcher Binary** | Downloaded from `launcher.hytale.com`. SHA-256 checksums computed and pinned in wrapper.nix. |
| **No Circumvention** | No bypassing of technical protections, DRM, or anti-cheat systems. |
| **No Modifications** | Binary runs unmodified in FHS sandbox. No decompilation, reverse engineering, or code injection. |

*Referenced: [Terms of Service v2.2](https://hytale.com/terms-of-service) & [EULA v2.3](https://hytale.com/eula) (Effective January 13, 2026)*

### License

**This Repository**: [MIT License](LICENSE) - Covers only the Nix expressions and shell scripts.

**Hytale Launcher**: Proprietary software governed by [Hytale's EULA](https://hytale.com/eula).

### Trademarks

Hytale® and Hypixel Studios® are trademarks of Hypixel Studios Canada Inc. Used for identification purposes only.

### Disclaimer

This software is provided "as is", without warranty of any kind. Users must ensure their use complies with applicable terms and local laws.
