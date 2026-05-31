# Device Targets

This directory defines bootstrap image targets. Each file under `by-name/`
becomes:

- a NixOS configuration under `nixosConfigurations.<name>`
- an image build target under `legacyPackages.${system}.<name>`

For example:

```sh
nix build .#nixos-hinlink-h88k
nix build .#legacyPackages.x86_64-linux.nixos-hinlink-h88k
```

The `${system}` in `legacyPackages.${system}` is the build host system used by
the disko image builder. It is not the board model. This lets the image builder
run a QEMU VM matching the host architecture while producing the requested image. You may need extra system-binfmt support on x86_64-linux for evaluating the aarch64-linux derivation on the target system.

# Add a New Target
RK3588 targets are generic as long as the board has a mainline-style device
tree. Existing RK3588 device files mostly differ by `hardware.deviceTree.dtsFile`
plus small board-specific firmware, U-Boot, serial, and bootloader settings.

These targets also set a short default hostname with
`networking.hostName = lib.mkDefault "<host>"`. When a matching
`hosts/by-name/<host>.nix` exists, the bootstrapped board can later run
`nixos-rebuild switch --flake <path-to-repo>` without spelling out `.#<host>`.
