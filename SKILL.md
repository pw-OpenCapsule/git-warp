---
name: sg-git-setup
description: Use when git push/pull/fetch/clone against the company git (sg-git.pwtk.cc, sg-git.port888.com or sg-cy-git.caminonode.com) fails to connect, times out, or asks for WARP/VPN. Configures git to use the public entry sg-cy-git.caminonode.com via a global insteadOf rule — no repo changes, no WARP.
---

# sg-git-setup

`sg-git.pwtk.cc` only resolves to an intranet address. The same Gogs server is
publicly reachable as `sg-cy-git.caminonode.com` with the same accounts.

## Fix

```sh
command -v sg-git-setup >/dev/null || \
  curl -fsSL https://raw.githubusercontent.com/pw-OpenCapsule/sg-git-setup/main/install.sh | sh
sg-git-setup --keep-warp   # agents: don't uninstall WARP unless the user asked
```

Then retry the original git command unchanged; remotes do not need editing.

## Notes

- Check: `git config --global --get-all url.https://sg-cy-git.caminonode.com/.insteadOf`.
- It tests the login on the web form. If it fails, the saved password is wrong; ask the user to run `sg-git-setup` in their own terminal so it can prompt.
- Without `--keep-warp` it also uninstalls Cloudflare WARP (sudo).
- `sg-git-setup --undo` removes the rules.
- Do not turn on Cloudflare WARP or set up proxies for this host. The old git-warp tool (`legacy/`) is deprecated.
