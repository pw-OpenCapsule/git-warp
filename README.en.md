# sg-git-setup

The company git (Gogs) has a public entry, `sg-cy-git.caminonode.com`. It is the same server as `sg-git.pwtk.cc` (formerly `sg-git.port888.com`), with the same accounts, and needs no WARP, VPN or proxy.

This tool only changes global git config; no repository needs to be touched. Old URLs are rewritten to the new host automatically, so `pull`, `push` and `clone` keep working.

## Install

Run inside any company repo:

```sh
curl -fsSL https://raw.githubusercontent.com/pw-OpenCapsule/sg-git-setup/main/install.sh | sh
```

It installs `sg-git-setup` to `~/.local/bin` and adds `url.https://sg-cy-git.caminonode.com/.insteadOf` rules for the old https and `git@host:` URLs. It removes the old `http.https://sg-git.pwtk.cc/.proxy`, copies any saved sg-git credentials to the new host, and verifies access with `git ls-remote`. It also removes the old git-warp transparent mode from your shell rc (backed up as `*.bak-git-warp`).

```sh
sg-git-setup                 # re-run setup / verify
sg-git-setup <repo-url>      # verify against a specific repo
sg-git-setup --undo          # remove the rewrite rules
```

## Formerly git-warp

This repo used to be git-warp, which toggled Cloudflare WARP to reach the intranet host. It is no longer needed; the code lives in [legacy/](legacy/) and is unmaintained.
