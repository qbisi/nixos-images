{
  lib,
  config,
  self,
  inputs,
  ...
}:
{
  perSystem =
    {
      config,
      lib,
      system,
      ...
    }:
    {
      legacyPackages = import ./top-level.nix {
        pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            (self: super: {
              armTrustedFirmwareRK3588 = super.armTrustedFirmwareRK3588.overrideAttrs (prev: {
                src = super.fetchFromGitLab {
                  domain = "gitlab.collabora.com";
                  owner = "hardware-enablement/rockchip-3588";
                  repo = "trusted-firmware-a";
                  rev = "v2.12";
                  hash = "sha256-PCUKLfmvIBiJqVmKSUKkNig1h44+4RypZ04BvJ+HP6M=";
                };
                makeFlags = [ "AS=gcc" ] ++ prev.makeFlags;
              });
            })
          ];
        };
      };
    };
}
