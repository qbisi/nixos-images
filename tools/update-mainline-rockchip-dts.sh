#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
target_dir="$repo_root/dts/mainline/rockchip"
staging_dir="$(mktemp -d)"
trap 'rm -rf -- "$staging_dir"' EXIT

export DTS_UPDATE_REPO_ROOT="$repo_root"
# shellcheck disable=SC2016
kernel_src="$(
  nix build \
    --impure \
    --no-link \
    --option connect-timeout 30 \
    --print-out-paths \
    --expr '
      let
        repoRoot = builtins.getEnv "DTS_UPDATE_REPO_ROOT";
        lock = builtins.fromJSON (builtins.readFile (repoRoot + "/flake.lock"));
        nixpkgsNode = lock.nodes.${lock.nodes.${lock.root}.inputs.nixpkgs}.locked;
        nixpkgs = builtins.fetchTree nixpkgsNode;
        pkgs = import nixpkgs {
          system = builtins.currentSystem;
        };
      in
      pkgs.runCommand "linux-${pkgs.linux_latest.version}-source-tree" {
        nativeBuildInputs = [ pkgs.gnutar pkgs.xz ];
      } (builtins.concatStringsSep "\n" [
        "if [[ -d ${pkgs.linux_latest.src} ]]; then"
        "  cp -a ${pkgs.linux_latest.src} \"$out\""
        "else"
        "  mkdir -p \"$out\""
        "  tar -xf ${pkgs.linux_latest.src} -C \"$out\" --strip-components=1"
        "fi"
      ])
    '
)"
source_dir="$kernel_src/arch/arm64/boot/dts/rockchip"

if [[ ! -d "$source_dir" ]]; then
  echo "error: Rockchip DTS directory not found in linux_latest.src: $source_dir" >&2
  exit 1
fi

shopt -s nullglob
source_files=(
  "$source_dir"/rk3588*.dts
  "$source_dir"/rk3588*.dtsi
  "$source_dir"/rockchip-pinconf.dtsi
)

if (( ${#source_files[@]} == 0 )); then
  echo "error: no matching RK3588 DTS files found in $source_dir" >&2
  exit 1
fi

if [[ ! -f "$source_dir/rockchip-pinconf.dtsi" ]]; then
  echo "error: rockchip-pinconf.dtsi not found in $source_dir" >&2
  exit 1
fi

for source_file in "${source_files[@]}"; do
  install -m 0644 -- "$source_file" "$staging_dir/"
done

mkdir -p -- "$target_dir"
find "$target_dir" -maxdepth 1 -type f \
  \( -name 'rk3588*.dts' -o -name 'rk3588*.dtsi' -o -name 'rockchip-pinconf.dtsi' \) \
  -delete
install -m 0644 -- "$staging_dir"/* "$target_dir/"

echo "Updated ${#source_files[@]} files from nixpkgs linux_latest.src."
