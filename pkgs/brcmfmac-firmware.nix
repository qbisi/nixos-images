{
  stdenv,
  fetchurl,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "brcmfmac-firmware";
  version = "unstable-2024-09-29";

  src = fetchFromGitHub {
    owner = "qbisi";
    repo = "brcmfmac_sdio-firmware";
    rev = "240139ab39e3b13b2676a7b0aabbcd268b82b4ea";
    sha256 = "sha256-cV5dR6bLU5pVvHGjdAQkanCH+TtwrgVv/PF8xMzUrqk=";
  };

  installPhase = ''
    install -d $out/lib/firmware/brcm
    install -m 644 * $out/lib/firmware/brcm/
  '';

  # Firmware blobs do not need fixing and should not be modified
  dontBuild = true;
  dontFixup = true;

  passthru = {
    compressFirmware = false;
  };
}
