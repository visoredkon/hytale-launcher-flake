# Unofficial Hytale Launcher Nix Flake for NixOS

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![NixOS](https://img.shields.io/badge/NixOS-Unstable-blue.svg)](https://nixos.org)

An open-source **Nix flake** that wraps the **official** Hytale Launcher for NixOS using an FHS-compatible runtime environment.

> ⚠️ **Disclaimer**
> This project is **not** affiliated with, endorsed by, or associated with Hypixel Studios Canada Inc. It is a community-maintained interoperability wrapper intended solely to enable platform compatibility.

---

## Overview

This repository provides a Nix flake that runs the official Hytale Launcher on NixOS. Since NixOS doesn't provide a traditional Filesystem Hierarchy Standard (FHS) environment that many Linux applications expect, this flake creates an FHS-compatible sandbox without modifying the launcher binary.

---

## What This Does (and Doesn't Do)

This is a simple compatibility wrapper for NixOS. It only provides the runtime environment needed to run the official launcher.

This project does **not**:

- Bypass authentication, DRM, or any security systems
- Enable offline play, cracks, or unauthorized access
- Modify or patch the Hytale launcher binary
- Provide mods, cheats, or gameplay modifications
- Redistribute Hytale binaries or assets

---

## Compliance Notes

This wrapper is designed to be compatible with Hytale's [Terms of Service](https://hytale.com/terms-of-service) and [EULA](https://hytale.com/eula). Here's how it works:

| Component               | Implementation                                                                                                                               |
| :---------------------- | :------------------------------------------------------------------------------------------------------------------------------------------- |
| **Authentication**      | Handled entirely by the official launcher. No credentials are accessed or intercepted by this wrapper.                                       |
| **Distribution**        | This repository only contains Nix code. No Hytale binaries or assets are included or redistributed.                                          |
| **Launcher Binary**     | Downloaded directly from official Hytale endpoints and verified with SHA-256 checksums from their API. Not modified or patched.             |
| **Runtime Environment** | Provides an FHS-compatible sandbox using `buildFHSEnv`. The launcher runs as-is without code injection, debugging, or reverse engineering. |

**Referenced Documents:**
- Terms of Service v2.2 (Effective January 13, 2026)
- EULA v2.3 (Effective January 13, 2026)

> **Note:** This is a technical implementation, not legal advice. Users are responsible for their own compliance with Hytale's terms.

---

## System Requirements

- Linux (`x86_64-linux`)
- Nix with flakes enabled

---

## Unfree License Notice

The Hytale Launcher is proprietary software with an unfree license. You must explicitly allow unfree packages in your Nix configuration.

### Option 1: Environment Variable (Recommended for testing)

```bash
NIXPKGS_ALLOW_UNFREE=1 nix run --impure github:visoredkon/hytale-launcher-flake
```

### Option 2: NixOS Configuration (System-wide)

```nix
# configuration.nix or in your flake's nixpkgs config
nixpkgs.config.allowUnfree = true;
```

### Option 3: Selective Allow

```nix
# configuration.nix or in your flake's nixpkgs config
nixpkgs.config.allowUnfreePredicate = pkg:
  builtins.elem (lib.getName pkg) [
    "hytale-launcher"
  ];
```

---

## Usage

### Run Without Installing (Ephemeral)

```bash
NIXPKGS_ALLOW_UNFREE=1 nix run --impure github:visoredkon/hytale-launcher-flake
```

### Manual Build

```bash
NIXPKGS_ALLOW_UNFREE=1 nix build --impure
./result/bin/hytale-launcher
```

### NixOS Integration

The overlay approach allows the package to use your system's nixpkgs configuration (including `allowUnfree` settings).

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    hytale-launcher = {
      url = "github:visoredkon/hytale-launcher-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, hytale-launcher, ... }: {
    nixosConfigurations.yourhost = nixpkgs.lib.nixosSystem {
      modules = [
        {
          # Add overlay to nixpkgs
          nixpkgs.overlays = [ hytale-launcher.overlays.default ];

          # Configure allowUnfree
          nixpkgs.config.allowUnfreePredicate = pkg:
            builtins.elem (lib.getName pkg) [
              "hytale-launcher"
            ];
        }

        # Now use it in your config
        {
          environment.systemPackages = [ pkgs.hytale-launcher ];
        }
      ];
    };
  };
}
```

### Home Manager Integration

```nix
{
  inputs = {
    home-manager.url = "github:nix-community/home-manager";
    hytale-launcher.url = "github:visoredkon/hytale-launcher-flake";
  };

  outputs = { home-manager, hytale-launcher, ... }: {
    homeConfigurations.youruser = home-manager.lib.homeManagerConfiguration {
      modules = [
        {
          # Add overlay to nixpkgs
          nixpkgs.overlays = [ hytale-launcher.overlays.default ];

          # Configure allowUnfree
          nixpkgs.config.allowUnfreePredicate = pkg:
            builtins.elem (lib.getName pkg) [ "hytale-launcher" ];
        }

        # Now use it in your config
        {
          home.packages = [ pkgs.hytale-launcher ];
        }
      ];
    };
  };
}
```

---

## Development & Maintenance

### Updating to Latest Launcher Version

This repository includes an automated update script that fetches the latest launcher version from Hytale's official API:

```bash
# Preview changes
./update-version.sh

# Commit changes
./update-version.sh --commit

# Commit and push
./update-version.sh --commit --push
```

The script automatically:
- Fetches version metadata from `https://launcher.hytale.com/version/release/launcher.json`
- Updates `version` and `sha256` hash in `wrapper.nix`
- Updates `flake.lock` with `nix flake update`
- Commits changes with conventional commit message (if `--commit` flag is used)

### Development Environment

Enter the development shell:

```bash
nix develop
```

Available commands:
- `nix build` - Build the package
- `nix fmt` - Format Nix and shell script files
- `nix flake check` - Run all checks (build + format validation)

---

## Trademarks

**Hytale** and **Hypixel Studios** are trademarks of Hypixel Studios Canada Inc.

Any trademarks, service marks, logos, or visual assets are used solely for identification purposes. All rights remain with their respective owners.

---

## Legal Notice

1. **License**: This repository (Nix expressions and shell scripts) is licensed under the [MIT License](LICENSE). The Hytale Launcher binary downloaded and executed by this wrapper is proprietary software governed by the Hytale End-User License Agreement.
2. **No Warranty**: This software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement.
3. **User Responsibility**: Users are responsible for ensuring their use of this tool complies with applicable Terms of Service and local laws in their jurisdiction.
