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

    printf '\nPreparing next boot from %s with user %s...\n' "$flake_path" "$username"

    if ! env USER="$username" ${config.system.build.nixos-rebuild}/bin/nixos-rebuild boot --flake "$flake_path" --accept-flake-config --impure; then
      printf '\nBootstrap setup failed during nixos-rebuild. Log in again on this TTY to retry.\n'
      exit 0
    fi

    if ! getent passwd "$username" >/dev/null; then
      if getent passwd 1000 >/dev/null; then
        printf '\nBootstrap setup prepared the next boot, but UID 1000 is already in use.\n'
        printf 'Create %s or set its password manually, then reboot.\n' "$username"
        exit 0
      fi

      extra_groups=
      for group in wheel root video audio dialout; do
        if getent group "$group" >/dev/null; then
          if [ -z "$extra_groups" ]; then
            extra_groups="$group"
          else
            extra_groups="$extra_groups,$group"
          fi
        fi
      done

      useradd_args=(
        --create-home
        --uid 1000
        --shell ${lib.escapeShellArg "${pkgs.bashInteractive}/bin/bash"}
      )

      if getent group users >/dev/null; then
        useradd_args+=(--gid users)
      fi

      if [ -n "$extra_groups" ]; then
        useradd_args+=(--groups "$extra_groups")
      fi

      if ! ${pkgs.shadow}/bin/useradd "''${useradd_args[@]}" "$username"; then
        printf '\nBootstrap setup prepared the next boot, but could not create user %s.\n' "$username"
        printf 'Create %s manually, then reboot.\n' "$username"
        exit 0
      fi
    else
      existing_uid="$(getent passwd "$username" | cut -d: -f3)"
      if [ "$existing_uid" != 1000 ]; then
        printf '\nBootstrap setup prepared the next boot, but user %s already exists with UID %s.\n' "$username" "$existing_uid"
        printf 'The configured system expects UID 1000. Fix the user manually, then reboot.\n'
        exit 0
      fi
    fi

    if ! printf '%s:%s\n' "$username" "$password" | ${pkgs.shadow}/bin/chpasswd; then
      printf '\nBootstrap setup prepared the next boot, but could not set the password for %s.\n' "$username"
      printf 'Run passwd %s manually.\n' "$username"
      exit 0
    fi

    home_dir="$(getent passwd "$username" | cut -d: -f6)"
    config_dest="$home_dir/nixos-config"

    if [ -z "$home_dir" ] || [ ! -d "$home_dir" ]; then
      printf '\nBootstrap setup prepared the next boot, but could not find home directory for %s.\n' "$username"
      printf 'Copy %s manually after reboot.\n' "$flake_path"
    elif [ -e "$config_dest" ]; then
      printf '\nConfiguration copy skipped: %s already exists.\n' "$config_dest"
    else
      if ! mkdir -p "$config_dest"; then
        printf '\nBootstrap setup prepared the next boot, but could not create %s.\n' "$config_dest"
        printf 'Copy %s manually after reboot.\n' "$flake_path"
      elif ! cp -R --no-preserve=mode,ownership "$flake_path"/. "$config_dest"/; then
        printf '\nBootstrap setup prepared the next boot, but could not copy %s to %s.\n' "$flake_path" "$config_dest"
        printf 'Copy it manually after reboot.\n'
      else
        primary_group="$(id -gn "$username")"
        chown -R "$username:$primary_group" "$config_dest"
        printf '\nCopied NixOS config to %s.\n' "$config_dest"
      fi
    fi

    unset password password_confirm

    printf '\nSetup complete. User %s is ready.\n' "$username"
    printf 'Reboot now to start the configured system. Some configuration, such as desktop services, only takes effect after reboot.\n'
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
