This folder contains basic nixos configuration that you can switch/deploy to after you have flashed you bootstrap nixos-image to your board.

# Switch Configuration locally
You can clone this repository and switch configuration locally using `nixos-rebuild switch --flake <path-to-repo>[.#<host>]`.

When `.#<host>` is omitted, `nixos-rebuild switch --flake <path-to-repo>` uses
the current system hostname as the NixOS configuration name. RK3588 bootstrap
images set a short default hostname with `networking.hostName = lib.mkDefault
"<host>"`, for example `e88a`, `f88q`, `r5t`, or `v1a`. If a matching
`hosts/by-name/<host>.nix` exists, a freshly flashed board can switch to its
post-bootstrap host configuration without spelling out the target:

```sh
nixos-rebuild switch --flake <path-to-repo>
```

To avoid fetching flake inputs from github, we will later use "flake archive" to cache flake inputs locally to bootstrap images.
Bootstrap images prompt on the first local tty login for a username and password, switch to this flake with `USER=<username>`, and set the password directly after the switch.

# Remote Deployment
Remote deploy via "colmena apply --on <host>", see "colmena apply --help" for details.
Before applying to a board:

1. Confirm the target host name from `hosts/by-name/`, `devices/by-name/`.
2. Check whether the board is a local-network SBC or a VPS.
3. Make sure you have connected the target usb typec-otg port and you local machine with usb cord. The target board bootstrap with usb-rndis server and fixed ip 10.0.10.1 on usb0 iface.
4. Decide whether the change requires reboot:
   - kernel, initrd, bootloader, device tree, firmware, and early boot changes usually need `--reboot`
   - user services and many NixOS option changes may not
5. For local-network SBC targets that may not reach the internet or cache server, prefer `--no-substitute`. VPS deployments usually do not need it.
