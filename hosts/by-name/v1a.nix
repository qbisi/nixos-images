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
    flake.source = lib.mkDefault inputs.nixpkgs;
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
    networkmanager = {
      enable = true;
      ensureProfiles.profiles = { };
    };
    nameservers = [ "223.5.5.5" ];
  };

  services = {
    usb-rndis.enable = true;
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

  environment.systemPackages = with pkgs; [
    ffmpeg
    alsa-utils
    v4l-utils
    evtest
    libinput
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

  system.stateVersion = "25.11";
}
