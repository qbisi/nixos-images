{
  lib,
  stdenv,
  cmake,
  ninja,
  pkg-config,
  qt6,
  kdePackages,
  systemd,
  copyDesktopItems,
  makeDesktopItem,
  offline-update,
}:

stdenv.mkDerivation rec {
  pname = "configuration";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./assets/alarm.mp3
      ./assets/configuration.svg
      ./CMakeLists.txt
      ./src
    ];
  };

  nativeBuildInputs = [
    cmake
    copyDesktopItems
    ninja
    pkg-config
    qt6.qttools
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtmultimedia
    kdePackages.breeze-icons
    systemd
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "configuration";
      desktopName = "Configuration";
      genericName = "System Configuration";
      comment = "Touch system configuration panel";
      exec = "configuration";
      icon = "configuration";
      terminal = false;
      categories = [
        "Settings"
        "System"
      ];
      startupNotify = true;
    })
  ];

  qtWrapperArgs = [
    "--set"
    "CONFIGURATION_OFFLINE_UPDATE_COMMAND"
    (lib.getExe offline-update)
    "--set"
    "CONFIGURATION_SYSTEMD_MOUNT_COMMAND"
    "${systemd}/bin/systemd-mount"
    "--set"
    "CONFIGURATION_SYSTEMCTL_COMMAND"
    "${systemd}/bin/systemctl"
  ];

  postInstall = ''
    install -Dm0644 ${./assets/configuration.svg} \
      $out/share/icons/hicolor/scalable/apps/configuration.svg
    install -Dm0644 ${./assets/alarm.mp3} \
      $out/share/configuration/alarm.mp3
  '';

  preFixup = ''
    qtWrapperArgs+=(
      --set CONFIGURATION_SOUND_CHECK_FILE "$out/share/configuration/alarm.mp3"
    )
  '';

  meta = {
    description = "Touch-friendly Qt 6 system configuration panel";
    license = lib.licenses.mit;
    mainProgram = "configuration";
    platforms = lib.platforms.linux;
  };
}
