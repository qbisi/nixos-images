{ config, lib, ... }:
{
  boot.loader = lib.mkDefault {
    efi.efiSysMountPoint = "/boot/efi";
    grub = {
      device = "nodev";
      efiSupport = true;
      efiInstallAsRemovable = true;
      extraConfig = ''
        serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1
        terminal_input --append serial
        terminal_output --append serial
      '';
    };
  };
}
