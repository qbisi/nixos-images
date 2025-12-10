{ fetchFromGitHub }:
fetchFromGitHub {
  owner = "armbian";
  repo = "build";
  rev = "fd0a6d7224ea02f72efd8d47ac27179460ae4bd4";
  nonConeMode = true;
  sparseCheckout = [
    "config/kernel/*.config"
    "patch/kernel/**/*.patch"
  ];
  hash = "sha256-GMUMdoWDCHzBHoDLhBRySVjL4RBZQKSI7g88XxIClOk=";
}
