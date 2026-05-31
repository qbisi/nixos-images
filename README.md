# Nixos-images

## Introduction

Generic nixos build/deploy/test framework for **ANY** rk3588-boards.
---

## Features

- Generic u-boot recipe for rk3588 boards with support of hdmi-video output, usb keyboard input, efi bootmenu, boot from nvme like edk2-rk3588 does.
- Refined linux kernel configuration for rk3588 boards with some out-of-tree kernel modules.
- Bootstrap nixos-images recipe that support extlinux/efi bootloaders and preset ext4/btrfs disk partitions.
- Easy to use first-login-setup and colmena remote deployment.
- Agent friendly deploy/test framework to debug your nixos configuration.
---

## Getting Started

### Option 1: Local Installation

1. Download the appropriate NixOS image from the [releases page](#link-to-releases).
2. Flash the image to your storage media (e.g., using `dd`, Etcher, etc.).
3. Boot the device — the root partition will resize automatically.

### Option 2: Cloud Server Installation

For cloud servers, you can use the [bin456789/reinstall](https://github.com/bin456789/reinstall) script to streamline the installation process. This script reboots the server into a minimal Alpine Linux environment that runs entirely in memory, and then uses `dd` to overwrite the disk with the NixOS image.

**Run the following one-liner to reinstall the NixOS image on your cloud server:**

```bash
## x86_64-linux
bash <(curl -L https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh) dd --password 123@@@ --img=https://github.com/qbisi/nixos-images/releases/download/2025.12.3/nixos-x86_64-generic.raw.xz && reboot
## aarch64
bash <(curl -L https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh) dd --password 123@@@ --img=https://github.com/qbisi/nixos-images/releases/download/2025.12.3/nixos-aarch64-uefi.raw.xz && reboot
```

## Project structure

This repository is organized around flake outputs:

```text
.
|-- flake.nix             # Top-level flake wiring for packages, modules, templates, hosts, and devices.
|-- overlays.nix          # Shared overlay entries used by NixOS modules and package builds.
|-- devices/              # Bootstrap image targets exposed as flake legacyPackages and nixosConfigurations.
|-- hosts/                # Installable/deployable host configurations and Colmena deployment notes.
|-- modules/              # Reusable NixOS modules for images, boot, disk layout, hardware, and services.
|-- pkgs/                 # Local package definitions: kernels, firmware, tools, and out-of-tree modules.
|-- dts/                  # Mainline, vendor, and dumped device-tree sources used for board support.
|-- patches/              # Kernel and U-Boot patches consumed by local package definitions.
|-- templates/            # `nix flake new` template for external configuration repositories.
`-- tools/                # Bring-up and maintenance tooling that is not part of a NixOS module.
```

Use `hosts/` for post-bootstrap system configurations and remote deployment. See `hosts/README.md` for the local `nixos-rebuild` and Colmena deployment workflow.

## Build Images

Image targets are exposed under `legacyPackages.${system}.nixos-*`.

Common usage:

```sh
nix build .#nixos-x86_64-generic --accept-flake-config
nix build .#nixos-aarch64-uefi --accept-flake-config
nix build .#nixos-hinlink-h88k --accept-flake-config
