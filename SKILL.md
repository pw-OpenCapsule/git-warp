---
name: git-warp
description: Use when git push/pull/fetch fails with "Couldn't connect to server" or "Failed to connect ... port 443" on a remote that's only reachable through Cloudflare WARP. It auto-connects WARP, runs the git command, then restores WARP to its previous state.
---

# git-warp

Some git remotes (private/internal servers) only answer when connected to
Cloudflare WARP. `git-warp` wraps a git command: if the remote host is
unreachable it brings WARP up, waits until the port is reachable, runs git,
then restores WARP to its entry state. If the host is already reachable, WARP
is left untouched.

## Usage — transparent mode (recommended)

Source the wrapper once from your shell rc, then just use git normally:

```sh
# ~/.zshrc or ~/.bashrc
source ~/.local/bin/git-warp.plugin.sh
```

```sh
git push
git pull
git fetch --all
git clone https://your-internal-host/group/repo.git
```

The wrapper only intercepts the network subcommands (`push`, `pull`, `fetch`,
`clone`, `ls-remote`, `remote update`); every other git subcommand passes
straight through to the real git with no added behavior. Because `git-warp`
only touches WARP when the remote is unreachable, public remotes (github.com)
are unaffected — only an internal-only remote triggers the auto-connect.

## Usage — explicit (no shell changes)

If you don't want to source the wrapper, call `git-warp` directly with the same
args you'd give git:

```sh
git-warp push origin main
git-warp pull
git-warp fetch --all
git-warp clone https://your-internal-host/group/repo.git
```

Any git arguments pass through unchanged. Exit code is git's exit code, or `2`
if WARP couldn't make the host reachable in time.

## Configuration

- `GIT_WARP_HOST` — target host (default: for `clone`, parsed from the clone
  URL argument; otherwise parsed from the `origin` remote URL).
- `GIT_WARP_PORT` — port to probe (default: `443`).
- `GIT_WARP_WAIT` — seconds to wait for WARP (default: `40`).

## Notes

- If the host is already reachable, WARP is not touched.
- A `trap` restores WARP on exit, so it's restored even if git fails: it
  disconnects only if WARP was off on entry, otherwise it stays connected.
- It never disconnects a WARP session it didn't open.
- The transparent `git()` function uses `command git` internally so it never
  recurses into itself.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/pw-OpenCapsule/git-warp/main/install.sh | sh
```

Requires `warp-cli`, `nc` (netcat), and `git`.
