# Agent Notes

- Prefer an out-of-tree kernel module, as with `panel-simple-dsi`, over carrying a kernel patch when adding or backporting a driver.
- For flake repositories, always `git add` untracked files before evaluating so Nix can see them.
- To validate system changes on a host, run `colmena apply --on $host`. For local-network SBC targets that may not reach the internet or cache server, prefer `colmena apply --no-substitute --on $host`; VPS deployments usually do not need `--no-substitute`. Add `--reboot` for changes that need a reboot to take effect; with `--reboot` and no explicit goal, Colmena defaults the goal to `boot` and waits for the node to come back up.
