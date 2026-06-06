{
  config,
  pkgs,
  lib,
  self,
  ...
}:
{
  imports = [
    ../../devices/by-name/nixos-ido-evb3588-v1a.nix
    ../../profiles/desktop.nix
  ];

  system.symlinkConfig.enable = true;

  services = {
    openssh = {
      enable = true;
      openFirewall = true;
    };
  };

  users = {
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

  nix.settings = {
    trusted-users = [ config.users.users.admin.name ];
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
}
