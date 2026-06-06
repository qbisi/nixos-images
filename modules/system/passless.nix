{
  lib,
  config,
  ...
}:
{
  options = {
    system.passless = {
      enable = lib.mkEnableOption "passless system for remote deployment";
    };
  };

  config = lib.mkIf config.system.passless.enable {
    users.users.root = {
      hashedPassword = "";
    };

    services = {
      openssh = {
        enable = true;
        openFirewall = true;
        settings = {
          PermitRootLogin = "yes";
          PermitEmptyPasswords = "yes";
        };
      };
    };

    security.pam.services.sshd.allowNullPassword = true;
  };
}
