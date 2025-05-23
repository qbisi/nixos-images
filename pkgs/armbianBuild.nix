{ fetchFromGitHub }:
fetchFromGitHub {
  owner = "armbian";
  repo = "build";
  tag = "v25.5.1";
  nonConeMode = true;
  sparseCheckout = [
    "config/kernel/*.config"
    "patch/kernel/**/*.patch"
  ];
  hash = "sha256-Xrd2PElurtTtSQ2WqI7GdW0oOs/ZrufHxgwYQ0fD91A=";
}
