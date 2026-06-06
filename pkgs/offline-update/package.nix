{
  lib,
  writeShellApplication,
  coreutils,
  jq,
  nix,
  util-linux,
}:

writeShellApplication {
  name = "offline-update";

  runtimeInputs = [
    coreutils
    jq
    nix
    util-linux
  ];

  text = ''
    set -euo pipefail

    image_mount="''${OFFLINE_UPDATE_IMAGE_MOUNT:-/run/offline-update/image}"
    state_dir="''${OFFLINE_UPDATE_STATE_DIR:-/var/lib/offline-update}"
    lock_path="''${OFFLINE_UPDATE_LOCK_PATH:-/run/offline-update.lock}"

    log() {
      printf 'offline-update: %s\n' "$*" >&2
    }

    usage() {
      cat >&2 <<EOF
    usage: offline-update {apply|boot} UPDATE_IMG

    Imports a source-free NixOS update image. The apply command activates it
    immediately, while boot only makes it the default profile for the next boot.
    The update image must contain manifest.json, nix-support/store-paths,
    nix-support/registration, and a /nix/store payload.
    EOF
    }

    require_root() {
      if [ "$(${coreutils}/bin/id -u)" != 0 ]; then
        log "must run as root"
        exit 1
      fi
    }

    mount_update_image() {
      local image="$1"

      if [ ! -f "$image" ]; then
        log "$image is not an update image"
        exit 1
      fi

      ${coreutils}/bin/mkdir -p "$image_mount"

      if ${util-linux}/bin/findmnt -rn --mountpoint "$image_mount" >/dev/null; then
        ${util-linux}/bin/umount "$image_mount"
      fi

      ${util-linux}/bin/mount -o loop,ro "$image" "$image_mount"
      image_mounted=1
    }

    cleanup() {
      local status=$?

      restore_store_readonly || true

      if [ "''${image_mounted:-0}" = 1 ]; then
        ${util-linux}/bin/umount "$image_mount" || true
      fi

      exit "$status"
    }

    make_store_writable() {
      local options

      if ! store_mount="$(${util-linux}/bin/findmnt -rn -o TARGET --target /nix/store)"; then
        log "cannot find /nix/store mount"
        exit 1
      fi

      if ! options="$(${util-linux}/bin/findmnt -rn -o OPTIONS --target /nix/store)"; then
        log "cannot read /nix/store mount options"
        exit 1
      fi

      case ",$options," in
        *,ro,*)
          log "temporarily remounting $store_mount writable"
          ${util-linux}/bin/mount -o remount,bind,rw "$store_mount"
          store_remounted=1
          ;;
      esac
    }

    restore_store_readonly() {
      if [ "''${store_remounted:-0}" = 1 ]; then
        log "restoring $store_mount read-only"
        ${util-linux}/bin/mount -o remount,bind,ro "$store_mount"
        store_remounted=0
      fi
    }

    validate_manifest() {
      manifest="$image_mount/manifest.json"
      store_paths="$image_mount/nix-support/store-paths"
      registration="$image_mount/nix-support/registration"

      if [ ! -f "$manifest" ]; then
        log "manifest.json is missing"
        exit 1
      fi

      if [ ! -f "$store_paths" ]; then
        log "nix-support/store-paths is missing"
        exit 1
      fi

      if [ ! -f "$registration" ]; then
        log "nix-support/registration is missing"
        exit 1
      fi

      profile="$(${jq}/bin/jq -er '.profile' "$manifest")"
      protocol="$(${jq}/bin/jq -er '.protocol' "$manifest")"
      source_included="$(${jq}/bin/jq -r '.sourceIncluded' "$manifest")"
      flake_inputs_included="$(${jq}/bin/jq -r '.flakeInputsIncluded' "$manifest")"

      if [ "$protocol" != 1 ]; then
        log "unsupported update protocol: $protocol"
        exit 1
      fi

      case "$profile" in
        /nix/store/*) ;;
        *)
          log "manifest profile is not a Nix store path: $profile"
          exit 1
          ;;
      esac

      if [ "$source_included" != false ] || [ "$flake_inputs_included" != false ]; then
        log "refusing update image that declares source payloads"
        exit 1
      fi
    }

    import_store_paths() {
      local paths=()

      log "copying missing store paths"
      mapfile -t paths < "$store_paths"
      make_store_writable

      for path in "''${paths[@]}"; do
        [ -n "$path" ] || continue

        case "$path" in
          /nix/store/*) ;;
          *)
            log "invalid store path in closure list: $path"
            exit 1
            ;;
        esac

        if [ ! -e "$path" ]; then
          if [ ! -e "$image_mount$path" ]; then
            log "payload is missing $path"
            exit 1
          fi

          ${coreutils}/bin/cp -a "$image_mount$path" /nix/store/
        fi
      done

      log "loading Nix registration metadata"
      ${nix}/bin/nix-store --load-db < "$registration"
      restore_store_readonly
    }

    set_profile() {
      local mode="$1"
      local mode_name
      local state_manifest
      local state_timestamp

      if [ ! -x "$profile/bin/switch-to-configuration" ]; then
        log "$profile is not a valid NixOS profile"
        exit 1
      fi

      case "$mode" in
        switch)
          mode_name="activation"
          state_manifest="$state_dir/last-applied.json"
          state_timestamp="$state_dir/last-applied-at"
          ;;
        boot)
          mode_name="boot profile update"
          state_manifest="$state_dir/last-boot.json"
          state_timestamp="$state_dir/last-boot-at"
          ;;
        *)
          log "unsupported update mode: $mode"
          exit 1
          ;;
      esac

      ${coreutils}/bin/mkdir -p "$state_dir"

      previous_profile="$(${coreutils}/bin/readlink -e /nix/var/nix/profiles/system 2>/dev/null || true)"
      if [ -n "$previous_profile" ]; then
        printf '%s\n' "$previous_profile" > "$state_dir/previous-profile"
      fi

      log "setting system profile to $profile"
      ${nix}/bin/nix-env --profile /nix/var/nix/profiles/system --set "$profile"

      log "running switch-to-configuration $mode for $profile"
      if ! "$profile/bin/switch-to-configuration" "$mode"; then
        log "$mode_name failed"
        if [ -n "$previous_profile" ]; then
          log "restoring previous system profile link"
          ${nix}/bin/nix-env --profile /nix/var/nix/profiles/system --set "$previous_profile" || true
        fi
        exit 1
      fi

      ${coreutils}/bin/cp "$manifest" "$state_manifest"
      ${coreutils}/bin/date --iso-8601=seconds > "$state_timestamp"
      log "$mode_name complete"
    }

    run_update() {
      local mode="$1"
      local update_img="$2"

      require_root

      exec 9>"$lock_path"
      if ! ${util-linux}/bin/flock -n 9; then
        log "another update is already running"
        exit 0
      fi

      image_mounted=0
      store_remounted=0
      trap cleanup EXIT

      mount_update_image "$update_img"
      validate_manifest
      import_store_paths
      set_profile "$mode"
    }

    command="''${1:-}"
    case "$command" in
      apply)
        shift
        if [ "$#" -ne 1 ]; then
          usage
          exit 2
        fi
        run_update switch "$1"
        ;;
      boot)
        shift
        if [ "$#" -ne 1 ]; then
          usage
          exit 2
        fi
        run_update boot "$1"
        ;;
      -h|--help|help)
        usage
        ;;
      *)
        usage
        exit 2
        ;;
    esac
  '';

  meta = {
    description = "Source-free offline NixOS updater for removable update images";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
