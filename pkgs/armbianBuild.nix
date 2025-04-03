{ fetchFromGitHub }:
fetchFromGitHub {
  owner = "armbian";
  repo = "build";
  rev = "95b8c4cc8c252d4f9dbcbc17611e835550b3fa70";
  nonConeMode = true;
  sparseCheckout = [
    "config/kernel/*.config"
    "patch/kernel/**/*.patch"
  ];
  hash = "sha256-wMJpDgvJHTp4HhteYTuTblMmTdYxLqVFu8hpoiUuoYM=";
}
