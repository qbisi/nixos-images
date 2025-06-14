{ fetchFromGitHub }:
fetchFromGitHub {
  owner = "armbian";
  repo = "build";
  tag = "v25.8.0-trunk.130";
  nonConeMode = true;
  sparseCheckout = [
    "config/kernel/*.config"
    "patch/kernel/**/*.patch"
  ];
  hash = "sha256-3v5ohEiOEK3mmph2xSl4LTo2mcXU+LGQhHYnmUFa0gQ=";
}
