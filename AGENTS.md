# Agent Notes

- Prefer an out-of-tree kernel module, as with `panel-simple-dsi`, over carrying a kernel patch when adding or backporting a driver.
- For flake repositories, always `git add` untracked files before evaluating so Nix can see them.
- Start minimal and grow by addition when creating skills. Do not generate a comprehensive default skill and then subtract. Add only the rules, commands, or examples that are justified by the current context.
