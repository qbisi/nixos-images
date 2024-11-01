# Rebuild or Deploy you own nixos configuration

This document is for people unfamiliar with nix/nixpkgs/nixos and want to set their own configuration of nixos on sbc, pc or vps.

## Through nixos-rebuild

This flake souce is by default rsynced to /etc/nixos, thus one can rebuild their system immediately in bootstrap images.
The main example configuration file is `/etc/nixos/hosts/<system>/<edit>`.
One can change the default nixos user name and passwd to their own preference.

```
nixos-rebuild switch
```

## Use this repo as your nixos-config center

It is recommended to clone this repository to your home directory. And you can change your configuration via
```
nixos-rebuild switch --flake ~/nixos-images
```

Alternatively, you can intergrate this repo into your own nixos-configuration.