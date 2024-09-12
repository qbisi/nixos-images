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
    self.nixosModules.hybrid-btrfs
  ];

  boot = {
    growPartition.enable = true;
    kernelParams = [
      "net.ifnames=0"
      "console=ttyS0"
      "console=tty1"
      "earlycon"
    ];
    loader = {
      efi.efiSysMountPoint = "/boot/efi";
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        device = "/dev/disk/by-diskseq/1";
        extraConfig = ''
          serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1
          terminal_input --append serial
          terminal_output --append serial
        '';
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
