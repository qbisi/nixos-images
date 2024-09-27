{
  stdenv,
  fetchurl,
  fetchFromGitHub,
  p7zip,
}:
stdenv.mkDerivation rec {
  pname = "brcmfmac_sdio-firmware";
  version = "v0.0.1";

  src1 = fetchurl {
    url = "https://files.kos.org.cn/rockchip/sw799/sw799-ap6236驱动.7z";
    hash = "sha256-ZvDxSRyN1N/oId0q5rXR378N9eWs6b0BpNFE4C1Ww8c=";
  };

  src2 = fetchFromGitHub {
      owner = "LibreELEC";
      repo = "brcmfmac_sdio-firmware";
      rev = "88e46425ef489513c0b8bf7c2747d262367be1cc";
      sha256 = "sha256-VTS1yIjnphliObjjoWDi+4Uh2iNcxqrw1uyMWmcpKxw=";
  };

  srcs = [src1 src2]; 

  sourceRoot = "."; 

  unpackCmd = ''
    ${p7zip}/bin/7za x -oap6236 ${src1}
  '';

  installPhase = ''
    install -d $out/lib/firmware/brcm
    install -m 444 ap6236/brcm* $out/lib/firmware/brcm/
    install -m 444 ${src2}/* $out/lib/firmware/brcm/
  '';

  passthru = {
    compressFirmware = false;
  };
}