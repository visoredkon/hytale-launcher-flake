# Unofficial Hytale Launcher Nix Flake for NixOS

[![Compliance: Designed for ToS Safety](https://img.shields.io/badge/Compliance-ToS%20Design--Intent-green)](https://hytale.com/terms-of-service)
[![License: Unspecified](https://img.shields.io/badge/License-Unspecified-lightgrey)](#legal-notice)
[![NixOS](https://img.shields.io/badge/NixOS-Unstable-blue.svg)](https://nixos.org)

An uncertified, open-source **Nix flake** that provides an interoperability wrapper to execute the **official** Hytale Launcher on NixOS using an FHS-compatible runtime environment.

> ⚠️ **Disclaimer**
> This project is **not** affiliated with, endorsed by, or associated with Hypixel Studios Canada Inc. It is a community-maintained interoperability wrapper intended solely to enable platform compatibility.

---

## Overview

This repository provides a Nix flake that enables the lawful execution of the officially distributed Hytale Launcher on the NixOS operating system. NixOS deliberately does not provide a traditional Filesystem Hierarchy Standard (FHS) runtime environment, which many proprietary Linux applications implicitly rely on. The flake supplies a controlled FHS-compatible execution environment without modifying the upstream software.

---

## Project Boundaries

The scope of this project is deliberately narrow and conservative. It exists solely to provide operating-system-level interoperability via Nix, without altering the behavior, distribution model, or trust boundaries of the official launcher.

This project does **not**:

- Replace, reimplement, or extend the functionality of the official Hytale launcher
- Modify, patch, hook, or inject code into Hytale binaries
- Bypass DRM, entitlement validation, or authentication systems
- Enable offline, cracked, or unauthorized access to Hytale services
- Provide gameplay modifications, cheats, or protocol alterations

Any functionality that falls under these categories is out of scope for this project.

---

## Terms of Service & EULA Design Intent

This project is designed in **good faith** to avoid behaviors restricted under Hypixel Studios Canada Inc.'s publicly available [Terms of Service](https://hytale.com/terms-of-service) and [End-User License Agreement](https://hytale.com/eula). The following statements describe technical _design intent_, not legal guarantees.

| Design Principle                  | Technical Behavior                                                                                                                                                                                                                                                |
| :-------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Authentication Isolation**      | The wrapper executes the official launcher binary without modification. All authentication, entitlement checks, and account handling remain exclusively within the official client. No credentials are accessed, intercepted, stored, or proxied by this project. |
| **Binary Integrity Preservation** | Launcher binaries are downloaded at runtime from official Hypixel-controlled endpoints and validated using SHA-256 checksums published by the official launcher metadata API. This project does not alter, patch, or instrument the downloaded binaries.          |
| **No Redistribution**             | This repository contains only Nix expressions and shell scripts. It does not ship, cache, mirror, or redistribute Hytale binaries, assets, or proprietary data.                                                                                                   |
| **No Reverse Engineering**        | The wrapper operates strictly as an execution environment. It does not perform decompilation, disassembly, binary instrumentation, debugging attachment, or runtime code injection.                                                                               |
| **Official Source Retrieval**     | All proprietary components are retrieved at runtime directly from official Hypixel-controlled infrastructure. No third-party mirrors are used or provided.                                                                                                        |

### Referenced Document Versions

The design-intent analysis above reflects the following document versions as published at the time of writing:

- **Terms of Service**: Version 2.2 (Effective January 13, 2026)
- **End-User License Agreement**: Version 2.3 (Effective January 13, 2026)

> **Interpretation Notice**
> The statements above reflect the authors' good-faith technical interpretation of the referenced documents as of their effective dates. This repository does not provide legal advice, does not claim authoritative interpretation of these documents, and makes no guarantees regarding future enforcement policies or document revisions.

---

## System Requirements

- Linux (`x86_64-linux`)
- Nix with flakes enabled

---

## Usage

### Run Without Installing (Ephemeral)

```bash
nix run github:visoredkon/hytale-launcher-flake
```

### Manual Build

```bash
nix build
./result/bin/hytale-launcher
```

### NixOS System Integration

```nix
{
  inputs.hytale-launcher.url = "github:visoredkon/hytale-launcher-flake";
}
```

```nix
environment.systemPackages = [
  hytale-launcher.packages.x86_64-linux.default
];
```

---

## Trademarks

**Hytale** and **Hypixel Studios** are trademarks of Hypixel Studios Canada Inc.

Any trademarks, service marks, logos, or visual assets are used solely for identification purposes. All rights remain with their respective owners.

---

## Legal Notice

1. **License**: No explicit license is granted for the scripts and Nix expressions in this repository unless stated otherwise. The Hytale Launcher binary downloaded and executed by this wrapper is proprietary software governed by the Hytale End-User License Agreement.
2. **No Warranty**: This software is provided "as is", without warranty of any kind, express or implied.
3. **User Responsibility**: Users are responsible for ensuring their use of this tool complies with applicable Terms of Service and local laws in their jurisdiction.
