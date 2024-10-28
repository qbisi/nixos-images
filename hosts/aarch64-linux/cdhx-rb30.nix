{
  config,
  pkgs,
  lib,
  modulesPath,
  self,
  inputs,
  ...
}:
{
  deployment = {
    targetHost = "cdhx-rb30";
    buildOnTarget = false;
    tags = [ "rk3399" ];
  };

  nixpkgs.config = {
    allowUnfree = true;
  };

  imports = [
    ../../devices/aarch64-linux/nixos-rockchip-cdhx-rb30-uboot-btrfs.nix
    ../../modules/config/desktop.nix
  ];

  users.users.nixos = {
    password = "nixos";
    # use mkpasswd to generate hashedPassword
    # hashedPassword = "$y$j9T$20Q2FTEqEYm1hzP10L1UA.$HLsxMJKmYnIHM2kGVJrLHh0dCtMz.TSVlWb0S2Ja29C";
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    openssh.authorizedKeys.keys = [ ];
  };

  users.users.root = {
    password = "root";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIc0M/36MG2YkGTPpx7nEc3gILV9VbovrRga1ig1P69b"
    ];
  };

  services.openssh = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [
    vim
    wget
    htop
    git
    neofetch
    vscode-fhs
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [ "@wheel" ];
  };

  system.stateVersion = "24.11";
}
