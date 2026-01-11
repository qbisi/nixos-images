{
  config,
  pkgs,
  lib,
  self,
  inputs,
  ...
}:
{
  imports = [
    "${inputs.nixos-images}/devices/by-name/nixos-radxa-rock-5b.nix"
    ../config/desktop.nix
  ];

  boot = {
    # you can override the kernel packages set in bootstrap image
    # kernelPackages = lib.mkForce (pkgs.linuxPackagesFor pkgs.linux_rkbsp_6_1);
    kernelPackages = lib.mkForce linuxPackages_latest;
  };

  users.users = {
    nixos = {
      password = "nixos";
      # use mkpasswd to generate hashedPassword
      # hashedPassword = "$y$j9T$20Q2FTEqEYm1hzP10L1UA.$HLsxMJKmYnIHM2kGVJrLHh0dCtMz.TSVlWb0S2Ja29C";
      isNormalUser = true;
      extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
      openssh.authorizedKeys.keys = [ ];
    };
    root = {
      openssh.authorizedKeys.keys = [ ];
    };
  };

  services.openssh.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    wget
    htop
    git
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = [
      "https://cache.qbisi.cc"
    ];
    trusted-public-keys = [
      "cache.qbisi.cc-1:xEChzP5k8fj+7wajY+e9IDORRTGMhViP5NaqMShGGjQ="
    ];
  };

  system.stateVersion = "26.05";
}
