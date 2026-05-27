# Agent Notes

- Prefer an out-of-tree kernel module, as with `panel-simple-dsi`, over carrying a kernel patch when adding or backporting a driver.
- For flake repositories, always `git add` untracked files before evaluating so Nix can see them.
- To validate system changes on a host, run `colmena apply --on $host`; reboot the system afterward if needed for the change to take effect.
