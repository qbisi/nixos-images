{
  config,
  lib,
  self,
  modulesPath,
  ...
}:
let
  flakeOutPaths =
    let
      collector =
        parent:
        map (
          child:
          [ child.outPath ] ++ (if child ? inputs && child.inputs != { } then (collector child) else [ ])
        ) (lib.attrValues parent.inputs);
    in
    lib.unique (lib.flatten (collector self));
in
{
  imports = [
    "${modulesPath}/profiles/minimal.nix"
    ./passless.nix
  ];

  nixpkgs.flake = {
    setFlakeRegistry = false;
    setNixPath = false;
  };

  system = {
    extraDependencies = flakeOutPaths;
    systemBuilderCommands = lib.mkAfter ''
      mkdir -p $out/nixos-config
      cp -r ${self}/ $out/nixos-config
    '';
  };

  disko = {
    memSize = lib.mkDefault 4096;

    imageBuilder = {
      enableBinfmt = true;
      kernelPackages = config.disko.imageBuilder.pkgs.linuxPackages;
      # extraPostVM = lib.mkAfter ''
      #   ${config.disko.imageBuilder.pkgs.xz}/bin/xz -z $out/*${config.disko.imageBuilder.imageFormat}
      # '';
    };

    bootImage = {
      imageSize = "4G";
      partLabel = lib.mkIf (builtins.getEnv "PARTLABEL" != "") (builtins.getEnv "PARTLABEL");
    };
  };

  boot = {
    growPartition.enable = true;
    espRelocation.enable = true;
    loader.grub.btrfsPackage = config.disko.imageBuilder.pkgs.btrfs-progs;
    initrd.availableKernelModules = lib.mkIf config.hardware.enableAllHardware [
      "mpt3sas"
      "hv_storvsc"
    ];
  };

  hardware.enableAllHardware = lib.mkDefault config.boot.kernelPackages.kernel.configfile.autoModules;

  services = {
    usb-rndis.enable = true;
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
}
