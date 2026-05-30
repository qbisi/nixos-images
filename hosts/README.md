This folder contains basic nixos configuration that you can switch/deploy to after you have flashed you bootstrap nixos-image to your board.

# Switch Configuration locally
You can clone this repository and switch configuration locally using `nixos-rebuild switch --flake <path-to-repo>[.#<host>]`.

To avoid fetching flake inputs from github, we will later use "flake archive" to cache flake inputs locally to bootstrap images.
We will later implement a switch your configuration prompt on your first login from tty based on this flake repo and your custom name/passwd.

# Remote Deployment
Remote deploy via "colmena apply --on <host>", see "colmena apply --help" for details.
Before applying to a board:

1. Confirm the target host name from `hosts/by-name/`, `devices/by-name/`, or Colmena nodes.
2. Check whether the board is a local-network SBC or a VPS.
3. Decide whether the change requires reboot:
   - kernel, initrd, bootloader, device tree, firmware, and early boot changes usually need `--reboot`
   - user services and many NixOS option changes may not
4. For local-network SBC targets that may not reach the internet or cache server, prefer `--no-substitute`. VPS deployments usually do not need it.
