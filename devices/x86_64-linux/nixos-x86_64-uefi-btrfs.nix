{ config
, pkgs
, lib
, modulesPath
, inputs
, self
, ...
}:
{
  imports = [
    (modulesPath + "/profiles/all-hardware.nix")
  ];

  disko = {
    enableConfig = true;
    profile.use = "btrfs";
  };

  boot = {
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
