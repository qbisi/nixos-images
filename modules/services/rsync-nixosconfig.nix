{
  lib,
  pkgs,
  self,
  ...
}:
{
  systemd.services.rsync-nixosconfigurations = {
    description = "Rsync this flake source to /etc/nixos";

    enable = lib.mkDefault true;
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = with pkgs; [ rsync ];
    script = ''
      rsync -a --delete --chmod=D770,F660 "${self}/" /etc/nixos
    '';
  };
}
