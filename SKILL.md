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

## Usage

```sh
git-warp push origin main
git-warp pull
git-warp fetch
```

Any git arguments pass through unchanged. Exit code is git's exit code, or `2`
if WARP couldn't make the host reachable in time.

## Configuration

- `GIT_WARP_HOST` — target host (default: parsed from the `origin` remote URL).
- `GIT_WARP_PORT` — port to probe (default: `443`).
- `GIT_WARP_WAIT` — seconds to wait for WARP (default: `40`).

## Notes

- If the host is already reachable, WARP is not touched.
- A `trap` restores WARP on exit, so it's restored even if git fails: it
  disconnects only if WARP was off on entry, otherwise it stays connected.
- It never disconnects a WARP session it didn't open.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/pw-OpenCapsule/git-warp/main/install.sh | sh
```

Requires `warp-cli`, `nc` (netcat), and `git`.
