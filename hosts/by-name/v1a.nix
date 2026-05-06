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

  imports = [
    "${self}/devices/by-name/nixos-ido-evb3588-v1a.nix"
    "${self}/modules/config/passless.nix"
  ];

  hardware = {
    graphics.enable = true;
  };

  networking = {
    firewall.enable = false;
    nftables.enable = true;
    nameservers = [ "223.5.5.5" ];
  };

  services = {
    usb-rndis.enable = true;
    desktopManager.plasma6.enable = true;
    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };
  };

  i18n.defaultLocale = "zh_CN.UTF-8";

  users = {
    defaultUserShell = pkgs.zsh;
    users = {
      admin = {
        name = "nix";
        initialPassword = "1234";
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

  environment.systemPackages = with pkgs; [
    ffmpeg
    alsa-utils
    v4l-utils
    iperf3
  ];

  documentation.enable = false;

  nix = {
    settings = {
      substituters = lib.mkForce [ ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
  };
}
