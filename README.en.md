# sg-git-setup

The company git (Gogs) has a public entry, `sg-git-src.pwtk.cc`. It is the same server as `sg-git.pwtk.cc` (formerly `sg-git.port888.com`), with the same accounts, and needs no WARP, VPN or proxy.

This tool only changes global git config; no repository needs to be touched. Old URLs are rewritten to the new host automatically, so `pull`, `push` and `clone` keep working.

## Install

Run inside any company repo:

```sh
curl -fsSL https://raw.githubusercontent.com/pw-OpenCapsule/sg-git-setup/main/install.sh | sh
```

Run it once; afterwards git just works, with no repo changes and no terminal restart. It installs `sg-git-setup` to `~/.local/bin` and adds `url.https://sg-git-src.pwtk.cc/.insteadOf` rules for the old https and `git@host:` URLs. It removes the old `http.https://sg-git.pwtk.cc/.proxy`, copies any saved sg-git credentials to the new host and tests them with a real login (prompting for username/password if needed). Once the login works it retires git-warp: the transparent mode is removed from your shell rc (backed up as `*.bak-git-warp`) and `git-warp` / `warp-run` become pass-through shims, so already-open terminals keep working. It then disconnects and uninstalls Cloudflare WARP (needs sudo; skip with `--keep-warp`).

```sh
sg-git-setup                 # re-run setup / verify
sg-git-setup --keep-warp     # leave Cloudflare WARP installed
sg-git-setup --undo          # remove the rewrite rules
```

## Formerly git-warp

This repo used to be git-warp, which toggled Cloudflare WARP to reach the intranet host. It is no longer needed; the code lives in [legacy/](legacy/) and is unmaintained.
