{
  config,
  pkgs,
  lib,
  self,
  inputs,
  inputs',
  ...
}:
{
  deployment = {
    targetHost = "10.0.10.1";
    targetUser = "root";
    buildOnTarget = false;
  };

  nixpkgs = {
    config.allowUnfree = true;
  };

  imports = [
    "${self}/devices/by-name/nixos-firefly-aio-3588q.nix"
    "${self}/modules/config/passless.nix"
  ];

  hardware = {
    deviceTree = {
      overlays = [
        # {
        #   name = "mipi-ili9881c-gt9xx-8inch";
        #   dtsFile = ../../dts/mainline/overlays/rk3588-mipi-ili9881c-gt9xx-8inch.dtso;
        # }
        {
          name = "mipi-yx4005";
          dtsFile = ../../dts/mainline/overlays/rk3588-mipi-yx4005.dtso;
        }
      ];
    };
    graphics.enable = true;
  };

  networking = {
    hostName = "f88q";
    firewall.enable = false;
    nftables.enable = true;
    nameservers = [ "223.5.5.5" ];
  };

  users = {
    defaultUserShell = pkgs.zsh;
    users = {
      admin = {
        name = "nix";
        initialPassword = "";
        uid = 1000;
        isNormalUser = true;
        linger = true;
        extraGroups = [
          "wheel"
          "root"
          "video"
          "audio"
          "dialout"
        ];
      };
    };
  };

  programs = {
    zsh = {
      enable = true;
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;
      ohMyZsh = {
        enable = true;
        theme = "gentoo";
        plugins = [
          "git"
          "history"
          "wd"
          "sudo"
        ];
      };
    };
    nix-ld.enable = true;
  };

  services = {
    sdrplayApi.enable = true;
    usb-rndis.enable = true;
    cage = {
      enable = true;
      program = "${inputs.optispectrum.packages."aarch64-linux".optispectrum}/bin/optispectrum --fullscreen";
      environment.LANG = "zh_CN.UTF-8";
      user = config.users.users.admin.name;
    };
  };

  i18n.defaultLocale = "zh_CN.UTF-8";

  environment.variables = {
    MESA_GLSL_VERSION_OVERRIDE = 330;
  };

  nix = {
    settings = {
      # disalbe official cache
      substituters = lib.mkForce [ ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
  };
}
