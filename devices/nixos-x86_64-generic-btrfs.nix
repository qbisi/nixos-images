{
  config,
  pkgs,
  lib,
  modulesPath,
  inputs,
  self,
  ...
}:
{
  nixpkgs = {
    system = "x86_64-linux";
  };

  imports = [
    (modulesPath + "/profiles/all-hardware.nix")
    ../modules/disko/hybrid-btrfs.nix
  ];

  boot = {
    growPartition.enable = true;
    kernelParams = [ "net.ifnames=0" ];
    loader = {
      efi.efiSysMountPoint = "/boot/efi";
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        device = "/dev/disk/by-diskseq/1";
      };
    };
  };

  users.users.root = {
    hashedPassword = "";
  };

  networking = {
    firewall.enable = false;
    useNetworkd = true;
  };

  systemd.network.networks."eth*" = {
    matchConfig.Name = "eth*";
    networkConfig = {
      DHCP = "yes";
    };
    linkConfig.RequiredForOnline = "no";
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "yes";
        PermitEmptyPasswords = "yes";
      };
    };
  };

  security.pam.services.sshd.allowNullPassword = true;

  environment.systemPackages = with pkgs; [
    vim
  ];

}
