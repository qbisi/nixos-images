{ fetchFromGitHub }:
fetchFromGitHub {
  owner = "armbian";
  repo = "build";
  rev = "5964e230a1c5d0a4424e84db9ba29dda1f89913e";
  nonConeMode = true;
  sparseCheckout = [
    "config/kernel/*.config"
    "patch/kernel/**/*.patch"
  ];
  hash = "sha256-Qi73Co6WiEOvBL83M9qFgebUIvy9/546zAgCoh0ngoQ=";
}
