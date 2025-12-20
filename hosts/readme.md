# Rebuild or Deploy you own nixos configuration

This document is for people unfamiliar with nix/nixpkgs/nixos and want to set their own configuration of nixos on sbc, pc or vps.

## Use this repo as your nixos-config center

You can clone this repository to your home directory. And then change your configuration via
```
nixos-rebuild switch --flake ~/nixos-images
```

Alternatively, you can intergrate this repo into your own nixos-configuration.

```
nix flake new -t github:qbisi/nixos-images nixos-config
```
