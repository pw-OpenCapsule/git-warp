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

## Batch scripts

For scripts that run many `git-warp` commands, wrap the whole script so WARP is
connected once and restored once:

```sh
git-warp batch --host your-internal-host -- ./scripts/update_repos.sh
GIT_WARP_HOST=your-internal-host git-warp batch -- ./scripts/update_repos.sh
```

Nested `git-warp` calls will see the host as already reachable and leave WARP
untouched, avoiding connect/disconnect for every repository.

## Other commands — `warp-run`

For non-git commands that also need the internal network (open a PR with `tea`
/ `glab`, call an internal API with `curl`, …), wrap them with `warp-run`. It
uses the same WARP toggle logic as `git-warp` (connect when unreachable, run the
command, restore WARP on exit):

```sh
warp-run tea pr create --base main --head feature ...
warp-run curl https://your-internal-host/api/...
```

`warp-run` has no default host — set `WARP_HOST` (or reuse `GIT_WARP_HOST`). Its
exit code is the wrapped command's, or `2` if WARP couldn't make the host
reachable.

### Auto-wrap extra commands (`WARP_WRAP_CMDS`)

Set `WARP_WRAP_CMDS` to a space-separated list of command names before sourcing
`git-warp.plugin.sh`; it defines a same-named shell function for each that routes
through `warp-run`, so the commands auto-route through WARP just like git:

```sh
export WARP_HOST=your-internal-host
export WARP_WRAP_CMDS="tea glab"
source ~/.local/bin/git-warp.plugin.sh
# now: tea pr create ...  /  glab mr create ...  auto-connect WARP
```

Empty by default — nothing extra is wrapped unless you opt in.

## Configuration

- `GIT_WARP_HOST` — git-warp target host (default: for `clone`, parsed from the
  clone URL argument; for `push`/`pull`/`fetch`/`ls-remote`, parsed from the
  remote argument in the command — e.g. `fetch gitlab dev` → the `gitlab`
  remote — resolved in the repo selected by any leading `git -C <path>`;
  otherwise from the `origin` remote URL). Leading git global options
  (`-C <path>`, `-c <kv>`, `--git-dir`, …) are parsed the way git does.
- `GIT_WARP_PORT` — port to probe (default: `443`).
- `GIT_WARP_WAIT` — seconds to wait for WARP (default: `40`).
- `GIT_WARP_DEBUG` — when set (e.g. `1`), print the resolved subcommand /
  remote / host and exit without touching WARP or git (for testing host
  inference).
- `WARP_HOST` — warp-run target host (no default; falls back to `GIT_WARP_HOST`).
- `WARP_PORT` / `WARP_WAIT` — warp-run port / wait (fall back to the `GIT_WARP_*`
  equivalents; defaults `443` / `40`).
- `WARP_WRAP_CMDS` — extra command names to wrap transparently via `warp-run`
  (space-separated, e.g. `"tea glab"`; empty by default).

## Notes

- If the host is already reachable, WARP is not touched.
- A `trap` restores WARP on exit, so it's restored even if git fails: it
  disconnects only if WARP was off on entry, otherwise it stays connected.
- It never disconnects a WARP session it didn't open.
- The transparent `git()` function uses `command git` internally so it never
  recurses into itself.

## Install

One command — installs the binaries and auto-activates transparent mode by
appending `source <plugin>` to the user's shell rc (idempotent; opt out with
`--no-activate` or `GIT_WARP_NO_ACTIVATE=1`):

```sh
curl -fsSL https://raw.githubusercontent.com/pw-OpenCapsule/git-warp/main/install.sh | sh
```

As an agent skill (`npx skills add pw-OpenCapsule/git-warp -y -g`) it does **not**
edit any shell rc — the agent calls `git-warp` / `warp-run` explicitly, or sources
the plugin manually.

Requires `warp-cli`, `nc` (netcat), and `git`.
