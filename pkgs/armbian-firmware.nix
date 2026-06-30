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
stdenvNoCC.mkDerivation {
  pname = "armbian-firmware";
  version = "unstable-2026-03-01";

  src = fetchFromGitHub {
    owner = "armbian";
    repo = "firmware";
    rev = "0b876d66db3933a192afbba17eb0f84cb62b4018";
    hash = "sha256-/JxCWvpRtGW4hwqqtDJ7OutyyQXMdkJ1h6vzDsrmCkc=";
  };

  installPhase = ''
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
