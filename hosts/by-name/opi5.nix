{
  config,
  pkgs,
  lib,
  self,
  inputs,
  ...
}:
{
  deployment = {
    targetHost = config.networking.hostName;
    buildOnTarget = false;
    tags = [ "rk3588" ];
  };

  imports = [
    "${self}/devices/by-name/nixos-xunlong-orangepi-5.nix"
    "${self}/modules/config/desktop.nix"
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
