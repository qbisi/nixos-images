{ fetchFromGitHub }:
fetchFromGitHub {
  owner = "armbian";
  repo = "build";
  rev = "ed1e2f2248b35ed52af042b4c14e4cc37098e03c";
  nonConeMode = true;
  sparseCheckout = [
    "config/kernel/*.config"
    "patch/kernel/**/*.patch"
  ];
  hash = "sha256-Boqqk605IPfIsQY1kmOPr5uhEF09wj7uESmRdaPp/oA=";
}
