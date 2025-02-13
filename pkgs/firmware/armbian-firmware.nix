{
  stdenvNoCC,
  lib,
  fetchFromGitHub,
  filters ? [ "*" ],
}:
let
  installFilter = f: ''
    find . -type f -path './${f}' -exec cp --parents {} $out/lib/firmware \;
  '';
in
stdenvNoCC.mkDerivation rec {
  pname = "armbian-firmware";
  version = "unstable-2025-01-31";

  src = fetchFromGitHub {
    owner = "armbian";
    repo = "firmware";
    rev = "e75d7b6e36696a7877111c02bd3497cbd2d5cb34";
    hash = "sha256-VhcrMBFpq2TM/XeiG22K+ZrN97Lv7m36J9Y/0W4lHrM=";
  };

  installPhase =
    ''
      mkdir -p $out/lib/firmware
    ''
    + lib.concatMapStringsSep "\n" installFilter filters;

  # Firmware blobs do not need fixing and should not be modified
  dontBuild = true;
  dontFixup = true;

  passthru = {
    compressFirmware = false;
  };

  meta = with lib; {
    description = "Firmware from Armbian";
    homepage = "https://github.com/armbian/firmware";
    # license = licenses.unfree;
    platforms = platforms.all;
  };
}
