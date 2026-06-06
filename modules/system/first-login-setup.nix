{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.system.firstLoginSetup;

  setupScript = pkgs.writeShellScript "nixos-first-login-setup" ''
    set -euo pipefail

    flake_path=${lib.escapeShellArg cfg.flakePath}

    if [ "$(id -u)" -ne 0 ]; then
      exit 0
    fi

    if [ ! -t 0 ] || [ ! -t 1 ]; then
      exit 0
    fi

    if [ -n "''${SSH_CONNECTION:-}" ] || [ -n "''${SSH_TTY:-}" ]; then
      exit 0
    fi

    tty_name="$(tty || true)"
    case "$tty_name" in
      /dev/tty*|/dev/hvc*|/dev/console) ;;
      *) exit 0 ;;
    esac

    if [ ! -e "$flake_path/flake.nix" ]; then
      printf '\nBootstrap setup skipped: %s does not contain flake.nix.\n' "$flake_path"
      exit 0
    fi

    printf '\nFirst-login NixOS setup\n'
    printf 'Choose the normal user name for this board, then set its password.\n\n'

    while true; do
      printf 'Username: '
      IFS= read -r username

      case "$username" in
        "")
          printf 'Username cannot be empty.\n'
          continue
          ;;
        root)
          printf 'Please choose a non-root username.\n'
          continue
          ;;
      esac

      if ! printf '%s\n' "$username" | grep -Eq '^[a-z_][a-z0-9_-]{0,31}$'; then
        printf 'Use a Linux username: lowercase letters, numbers, underscores, or hyphens; it must start with a letter or underscore.\n'
        continue
      fi

      break
    done

    while true; do
      printf 'Password: '
      IFS= read -r -s password
      printf '\nConfirm password: '
      IFS= read -r -s password_confirm
      printf '\n'

      if [ -z "$password" ]; then
        printf 'Password cannot be empty.\n'
        continue
      fi

      if [ "$password" != "$password_confirm" ]; then
        printf 'Passwords do not match.\n'
        continue
      fi

      break
    done

    printf '\nSwitching to %s with user %s...\n' "$flake_path" "$username"

    if ! env USER="$username" ${config.system.build.nixos-rebuild}/bin/nixos-rebuild switch --flake "$flake_path" --accept-flake-config --impure; then
      printf '\nBootstrap setup failed during nixos-rebuild. Log in again on this TTY to retry.\n'
      exit 0
    fi

    if ! printf '%s:%s\n' "$username" "$password" | chpasswd; then
      printf '\nBootstrap setup switched configuration, but could not set the password for %s.\n' "$username"
      printf 'Run passwd %s manually.\n' "$username"
      exit 0
    fi

    unset password password_confirm

    printf '\nSetup complete. User %s is ready.\n' "$username"
  '';
in
{
  options = {
    system.firstLoginSetup = {
      enable = lib.mkEnableOption "first-login bootstrap setup prompt";

      flakePath = lib.mkOption {
        type = lib.types.str;
        default = "/run/current-system/nixos-config";
        description = "Flake path used by the first-login setup prompt.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.loginShellInit = ''
      ${setupScript}
    '';
  };
}
