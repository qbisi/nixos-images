{ fetchFromGitHub }:
fetchFromGitHub {
  owner = "armbian";
  repo = "build";
  tag = "v25.5.0-trunk.505";
  nonConeMode = true;
  sparseCheckout = [
    "config/kernel/*.config"
    "patch/kernel/**/*.patch"
  ];
  hash = "sha256-PNcTOqGCUo7E9xNZZvmF+g91lFNzMlLnjQM8xguajzs=";
}
