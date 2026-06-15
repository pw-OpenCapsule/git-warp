# git-warp

Run git against a remote that's only reachable through Cloudflare WARP.
Auto-connects WARP when the remote is unreachable, runs your git command,
then restores WARP to its previous state.

## The problem

Some git remotes — private or internal servers — only answer when you're
connected to [Cloudflare WARP](https://developers.cloudflare.com/warp-client/).
When you're off WARP, `git push` / `pull` / `fetch` hangs and dies with
`Couldn't connect to server` or `Failed to connect ... port 443`.

Connecting WARP by hand before every git command (and remembering to turn it
back off) is tedious. `git-warp` does it for you, and only when needed.

## What it does

1. Figures out the remote host (from `GIT_WARP_HOST`, else `git remote get-url origin`).
2. If `host:port` is **already reachable**, it runs git and leaves WARP untouched.
3. Otherwise it runs `warp-cli connect`, waits until the port becomes reachable
   (up to `GIT_WARP_WAIT` seconds), then runs git.
4. On exit — success, git failure, or interruption — a `trap` **restores WARP
   to its entry state**: it disconnects only if WARP was off when you started,
   and leaves it connected if it was already on.

The exit code is git's own exit code, or `2` if WARP couldn't make the host
reachable in time.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/pw-OpenCapsule/git-warp/main/install.sh | sh
```

This installs `git-warp` to `~/.local/bin` (override with `BINDIR=/usr/local/bin`).
Make sure that directory is on your `PATH`.

As an agent skill (Claude Code / Cursor / Codex / Gemini CLI):

```sh
npx skills add pw-OpenCapsule/git-warp -y -g
```

## Usage

`git-warp` takes the exact arguments you'd give `git` — they pass through unchanged:

```sh
git-warp push origin main
git-warp pull
git-warp fetch --all
git-warp clone https://your-internal-host/group/repo.git
```

## Configuration

| Env var | Default | Meaning |
|---|---|---|
| `GIT_WARP_HOST` | host of `origin` remote | Target host to probe / route through WARP |
| `GIT_WARP_PORT` | `443` | Port to probe for reachability |
| `GIT_WARP_WAIT` | `40` | Seconds to wait for WARP to make the host reachable |

Host resolution order: `GIT_WARP_HOST` wins; otherwise the host is parsed from
`git remote get-url origin`. If you push to a remote other than `origin` and its
host differs, set `GIT_WARP_HOST` explicitly.

## Behavior notes

- **Already reachable → WARP untouched.** If the host answers without WARP,
  git-warp won't connect or disconnect anything.
- **State is restored via `trap`.** Even if git fails or you Ctrl-C, WARP returns
  to how it was on entry: off stays off, on stays on.
- It never disconnects a WARP session it didn't open.

## Requirements

- [`warp-cli`](https://developers.cloudflare.com/warp-client/get-started/) — the Cloudflare WARP client
- `nc` (netcat) — for the reachability probe
- `git`

## License

MIT
