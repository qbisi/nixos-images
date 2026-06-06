---
name: nixos-options
description: Use when exploring NixOS module options, option descriptions, types, defaults, declarations, or final config values in this repository, including options from imported modules such as Disko.
---

# NixOS Options

Use this skill to quickly inspect NixOS module option docs and evaluated config values in this repo.

## Quick Option Discovery

Prefer an existing evaluated host over constructing a standalone module eval. Any host importing `self.nixosModules.default` exposes the imported module options.

```sh
nix eval .#nixosConfigurations.<host>.options.<option-path> --apply builtins.attrNames --json
nix eval .#nixosConfigurations.<host>.options.<option-path>.<option>.description --raw
```

Use `.options...` to inspect available options, descriptions, types, defaults, and declarations:

```sh
nix eval .#nixosConfigurations.<host>.options.<option-path>.<option>.type.description --raw
nix eval .#nixosConfigurations.<host>.options.<option-path>.<option>.default --json
nix eval .#nixosConfigurations.<host>.options.<option-path>.<option>.declarations --json
```

Use `.config...` only when checking the final configured value for a specific host:

```sh
nix eval .#nixosConfigurations.<host>.config.<option-path>.<option> --json
```

For example, to explore Disko image builder options:

```sh
nix eval .#nixosConfigurations.nixos-x86_64-uefi.options.disko.imageBuilder --apply builtins.attrNames --json
nix eval .#nixosConfigurations.nixos-x86_64-uefi.options.disko.imageBuilder.pkgs.description --raw
```

## Bulk Metadata

To dump compact metadata for all options under a path:

```sh
nix eval .#nixosConfigurations.<host>.options.<option-path> --apply 'opts: builtins.mapAttrs (name: opt: { description = opt.description or null; type = opt.type.description or opt.type.name or null; declarations = map toString (opt.declarations or []); }) opts' --json
```
