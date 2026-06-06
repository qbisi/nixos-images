{
  config,
  lib,
  pkgs,
  ...
}:
{
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
        name =
          if
            builtins.elem (builtins.getEnv "USER") [
              "root"
              ""
            ]
          then
            "nix"
          else
            builtins.getEnv "USER";
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
