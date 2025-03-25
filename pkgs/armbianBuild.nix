{ fetchFromGitHub }:
fetchFromGitHub {
  owner = "armbian";
  repo = "build";
  rev = "db3615f7b0d784728f87e6a95c57607001790690";
  nonConeMode = true;
  sparseCheckout = [
    "config/kernel/*.config"
    "patch/kernel/**/*.patch"
  ];
  hash = "sha256-lWcag42GZhaWW4zZKeiWQO5Vh57QB/K6gCmdAZ1BIR0=";
}
