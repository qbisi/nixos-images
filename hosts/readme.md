# Rebuild or Deploy you own nixos configuration

This document is for people unfamiliar with nix/nixpkgs/nixos and want to set their own configuration of nixos on sbc, pc or vps.

## Through nixos-rebuild

```
git clone https://github.com/qbisi/nixos-images ~/nixos-images
nixos-rebuild switch --flake ~/nixos-images
```