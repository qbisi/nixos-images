{
  config,
  pkgs,
  lib,
  self,
  inputs,
  ...
}:
{
  deployment = {
    targetHost = "192.168.100.158";
    targetUser = "root";
    buildOnTarget = false;
  };

  nixpkgs = {
    flake.source = lib.mkDefault inputs.nixpkgs;
  };

  imports = [
    "${self}/devices/by-name/nixos-firefly-aio-3588q.nix"
    "${self}/modules/config/passless.nix"
  ];

  hardware = {
    graphics.enable = true;
  };

  networking = {
    hostName = "f88q";
    firewall.enable = false;
    nftables.enable = true;
    networkmanager = {
      enable = true;
      ensureProfiles.profiles = { };
    };
  };

  users = {
    defaultUserShell = pkgs.zsh;
    users = {
      admin = {
        name = "nix";
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

  programs = {
    zsh = {
      enable = true;
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;
    };
    nix-ld.enable = true;
  };

  services = {
    desktopManager.plasma6 = {
      mobile.enable = true;
    };
    displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
        autoLogin = {
          enable = true;
          user = config.users.users.admin.name;
          relogin = true;
        };
      };
    };
    usb-rndis.enable = true;
  };

  # disable hibernation
  systemd.sleep.settings.Sleep = {
    AllowSuspend = false;
    AllowHibernation = false;
  };

  environment.variables = {
    MESA_GLSL_VERSION_OVERRIDE = 330;
  };

  environment.plasma6.mobile.excludePackages = with pkgs.kdePackages; [
    alligator
    audiotube
    calindori
    kalk
    kasts
    kclock
    keysmith
    koko
    kongress
    krecorder
    ktrip
    kweather
    plasma-dialer
    qmlkonsole
    spacebar
  ];

  environment.systemPackages = with pkgs; [
    usbutils
    pciutils
    i2c-tools
    libgpiod
    alsa-utils
    minicom
    evtest
    libinput
    ethtool
    iperf3
    vim
    git
    python3
  ];

  environment.etc."xdg/kscreenlockerrc".text = lib.generators.toINI { } {
    Daemon = {
      RequirePassword = false;
      Autolock = false;
      LockOnResume = false;
    };
  };

  documentation = {
    enable = false;
    doc.enable = false;
    info.enable = false;
    man.enable = false;
    nixos.enable = false;
  };

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
  };

  system.stateVersion = "25.11";
}
