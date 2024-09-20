{ config
, pkgs
, lib
, modulesPath
, inputs
, self
, system
, ...
}:
let
  selfpkgs = self.packages.${system};
  fmt = config.disko.imageBuilder.imageFormat;
  oldImageName = "${config.disko.devices.disk.main.name}.${fmt}";
  newImageName = "${config.disko.profile.imageName}.${fmt}";
in
{
  networking.hostName = "hinlink-h88k";

  disko = {
    # memSize = 2048;
    memSize = 4096;
    imageBuilder.kernelPackages = pkgs.linuxPackages;
    imageBuilder.extraPostVM = lib.mkForce ''
      ${pkgs.coreutils}/bin/dd of=$out/${oldImageName} if=${selfpkgs.ubootHinlinkH88k}/u-boot-rockchip.bin bs=4K seek=8 conv=notrunc
      mv "$out/${oldImageName}" "$out/${newImageName}"
      ${pkgs.xz}/bin/xz -zk "$out/${newImageName}"
    '';
    enableConfig = true;
    profile.use = "btrfs";
    profile.espStart = "16M";
  };

  hardware = {
    firmware = [ selfpkgs.mali-panthor-g610-firmware ];
    deviceTree = {
      name = "rockchip/rk3588-hinlink-h88k.dtb";
      overlays = [
        { name = "h88k-enable-hdmiphy"; dtsFile = "${self}/dts/overlay/h88k-enable-hdmiphy.dts"; }
        { name = "h88k-enable-rs232-rs485"; dtsFile = "${self}/dts/overlay/h88k-enable-rs232-rs485.dts"; }
      ];
    };
  };

  boot = {
    kernelPackages = pkgs.linuxPackagesFor selfpkgs.linux_rkbsp_joshua;
    initrd.availableKernelModules = lib.mkForce [ "uas" ];
    growPartition.enable = true;
    kernelParams = [
      "net.ifnames=0"
      "console=ttyS2,1500000"
      "console=tty1"
      "earlycon"
    ];
    loader.grub.enable = true;
    loader.grub.extraConfig = ''
      serial --unit=0 --speed=1500000 --word=8 --parity=no --stop=1
      terminal_input --append serial
      terminal_output --append serial
    '';
  };

  users.users.root = {
    hashedPassword = "";
  };

  networking = {
    firewall.enable = false;
    useDHCP = false;
    useNetworkd = true;
  };

  systemd.network.networks."eth" = {
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
