# Nixos-images

## Introduction

Bootstrap NixOS images for servers, PCs, and SBCs. The provided images use a preset disk partition and will automatically expand to the full size after startup. The system has a passwordless root account that can be accessed locally or remotely, facilitating the deployment of your own NixOS configuration.

**Note:** The bootstrap system disables the firewall and allows root login via SSH without a password. Therefore, leaving the system unchanged on the public internet is unsafe and dangerous. You should set your own password or SSH key as soon as possible.

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
## x86_64-linux
bash <(curl -L https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh) dd --password 123@@@ --img=https://github.com/qbisi/nixos-images/releases/download/2025.12.2/nixos-x86_64-generic.raw.xz && reboot
## aarch64
bash <(curl -L https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh) dd --password 123@@@ --img=https://github.com/qbisi/nixos-images/releases/download/2025.12.2/nixos-aarch64-uefi.raw.xz && reboot
```

## Custom your own configuration
This project provide a init template that accept this repo as a flake inputs.
```
nix flake new -t github:qbisi/nixos-images my-nixos-config
```

## Building the Image Yourself

For advanced users looking to build a custom NixOS image from this Nix-based flake source, follow the steps below:

### Prerequisites

Ensure you have the following installed:

- **Nix**: Follow the installation instructions at [nixos.org](https://nixos.org/download.html).
- **Flakes Support**: Enable flakes in your Nix configuration by adding the following line to `/etc/nix/nix.conf`:

  ```ini
  experimental-features = nix-command flakes
  # required for build aarch64 images on x86_64-linux platform
  extra-platforms = aarch64-linux
  ```

### Build Process

Use the following command to build your desired NixOS image.
Replace `${device}` with the appropriate device type (e.g., x86_64-generic).
Replace `${partlabel}` with the appropriate media type (e.g., nvme, mmc, hdd).

```bash
PARTLABEL=${partlabel} nix build github:qbisi/nixos-images#nixos-${device} --impure
```

Once the build is complete, the resulting image will be located in the result directory:
```bash
ls result/
```
You should see the generated NixOS image file.
