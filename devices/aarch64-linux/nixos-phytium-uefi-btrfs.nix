{ config
, pkgs
, lib
, modulesPath
, inputs
, self
, system
, ...
}:
{

  disko = {
    enableConfig = true;
    profile.use = "btrfs";
  };

  boot = {
    kernelPackages = pkgs.linuxPackagesFor self.packages.${system}.linux_phytium_6_6;
    initrd.availableKernelModules = [ "uas" ];
    growPartition.enable = true;
    kernelParams = [
      "net.ifnames=0"
      "console=ttyS0"
      "console=tty1"
      "earlycon"
    ];
    loader.grub.enable = true;
  };

  users.users.root = {
    hashedPassword = "";
  };

  networking = {
    firewall.enable = false;
    useDHCP = false;
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
    grub2_efi
  ];

}
