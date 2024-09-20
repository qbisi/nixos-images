# Nixos-images

## Introduction

Bootstrap NixOS images for servers, PCs, and SBCs. The provided images use a preset disk partition and will automatically expand to the full size after startup. The system has a passwordless root account that can be accessed locally or remotely, facilitating the deployment of your own NixOS configuration.

**Note:** The bootstrap system disables the firewall and allows root login via SSH without a password. Therefore, leaving the system unchanged on the public internet is unsafe and dangerous. You should set your own password or SSH key as soon as possible.

You can use the Colmena tool to deploy your settings. Typical examples are provided in the repository: [github:/qbisi/nixos-config](https://github.com/qbisi/nixos-config).

---

## Features

- Pre-configured NixOS bootstrap images for different environments (servers, PCs, SBCs)
- Automatic disk resizing to fit the full available space after first boot
- Passwordless root access for easy configuration deployment
- Example configurations provided for Colmena deployment

---

## Getting Started

### Option 1: Local Installation (PC, SBC, Server)

1. Download the appropriate NixOS image from the [releases page](#link-to-releases).
2. Flash the image to your storage media (e.g., using `dd`, Etcher, etc.).
3. Boot the device — the root partition will resize automatically.

### Option 2: Cloud Server Installation

For cloud servers, you can use the [bin456789/reinstall](https://github.com/bin456789/reinstall) script to streamline the installation process. This script reboots the server into a minimal Alpine Linux environment that runs entirely in memory, and then uses `dd` to overwrite the disk with the NixOS image.

**Run the following one-liner to reinstall the NixOS image on your cloud server:**

```bash
bash <(curl -L https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh) dd --img=https://github.com/qbisi/nixos-images/releases/download/20240912/nixos-x86_64-generic-btrfs-scsi.raw.xz && reboot
```

## Building the Image Yourself

For advanced users looking to build a custom NixOS image from this Nix-based flake source, follow the steps below:

### Prerequisites

Ensure you have the following installed:

- **Nix**: Follow the installation instructions at [nixos.org](https://nixos.org/download.html).
- **Flakes Support**: Enable flakes in your Nix configuration by adding the following line to `/etc/nix/nix.conf`:

  ```ini
  experimental-features = nix-command flakes
  ```
  
### Build Process

Use the following command to build your desired NixOS image. Replace ${device} and ${mediatype} with the appropriate values (e.g., nixos-x86_64-generic-btrfs for device type and scsi for media type):

```bash
nix build github:qbisi/nixos-images#images.${device}-${mediatype}
```

Once the build is complete, the resulting image will be located in the result directory:
```bash
ls result/
```
You should see the generated NixOS image file.