{
  config,
  pkgs,
  lib,
  self,
  inputs,
  inputs',
  ...
}:
{
  deployment = {
    targetHost = "10.0.10.1";
    targetUser = "root";
    buildOnTarget = false;
  };

  nixpkgs = {
    flake.source = lib.mkDefault inputs.nixpkgs;
    config.allowUnfree = true;
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
    nameservers = [ "223.5.5.5" ];
  };

  users = {
    defaultUserShell = pkgs.zsh;
    users = {
      admin = {
        name = "nix";
        initialPassword = "";
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
      ohMyZsh = {
        enable = true;
        theme = "gentoo";
        plugins = [
          "git"
          "history"
          "wd"
          "sudo"
        ];
      };
    };
    nix-ld.enable = true;
  };

  services = {
    sdrplayApi.enable = true;
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
    v4l-utils
    minicom
    evtest
    libinput
    ethtool
    iperf3
    vim
    git
    python3
    inputs.spectrum.packages."aarch64-linux".spectrum
    inputs.optispectrum.packages."aarch64-linux".optispectrum
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
