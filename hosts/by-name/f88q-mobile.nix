{
  config,
  pkgs,
  lib,
  self,
  ...
}:
{
  imports = [
    ../../devices/by-name/nixos-firefly-aio-3588q.nix
  ];

  networking.hostName = "f88q-mobile";

  hardware = {
    deviceTree = {
      dtboBuildExtraIncludePaths = lib.mkAfter [ ../../dts/mainline ];
      overlays = [
        {
          name = "mipi-yx4005";
          dtsFile = ../../dts/mainline/overlays/rk3588-mipi-yx4005.dtso;
        }
      ];
    };
    graphics.enable = true;
  };

  services = {
    cage = {
      enable = true;
      program = "${pkgs.configuration}/bin/configuration";
      user = "root";
    };
  };
}
