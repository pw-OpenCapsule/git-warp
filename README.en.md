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

1. Figures out the remote host (from `GIT_WARP_HOST`; for `clone`, from the
   clone URL argument; otherwise from `git remote get-url origin`).
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

This installs `git-warp` and the transparent-mode wrapper `git-warp.plugin.sh`
to `~/.local/bin` (override with `BINDIR=/usr/local/bin`). Make sure that
directory is on your `PATH`.

As an agent skill (Claude Code / Cursor / Codex / Gemini CLI):

```sh
npx skills add pw-OpenCapsule/git-warp -y -g
```

## Usage — transparent mode (recommended)

Source the installed wrapper from your shell rc, then **just use git normally**:

```sh
# add to ~/.zshrc or ~/.bashrc:
source ~/.local/bin/git-warp.plugin.sh
```

(The installer prints this exact line; re-run it with `--activate` to append it
for you instead of editing your rc by hand.)

Now your everyday commands transparently route through WARP when needed:

```sh
git push
git pull
git fetch --all
git clone https://your-internal-host/group/repo.git
```

The wrapper only intercepts the **network** subcommands (`push`, `pull`,
`fetch`, `clone`, `ls-remote`, and `remote update`). Every other subcommand
(`commit`, `status`, `add`, `log`, `diff`, …) is passed straight through to the
real git with **zero added behavior or latency**. And because `git-warp` only
touches WARP when the remote is actually unreachable, public remotes like
`github.com` are completely unaffected — only an internal-only remote triggers
the auto-connect.

### Without changing your shell (explicit fallback)

If you'd rather not source anything, call `git-warp` directly — it takes the
exact arguments you'd give `git`:

```sh
git-warp push origin main
git-warp pull
git-warp fetch --all
git-warp clone https://your-internal-host/group/repo.git
```

## Other commands (not just git)

Other commands that need the internal network — opening a PR, calling an
internal API — can use the same WARP logic via `warp-run`: it brings WARP up
when the target host is unreachable, runs your command, then restores WARP.

```sh
# open a PR
warp-run tea pr create --base main --head feature ...
warp-run glab mr create ...

# call an internal API
warp-run curl https://your-internal-host/api/...
```

`warp-run` has **no default host** — set `WARP_HOST` (or reuse `GIT_WARP_HOST`):

```sh
export WARP_HOST=your-internal-host
```

### Automate: make these commands auto-route through WARP too

Add the command names to `WARP_WRAP_CMDS` (space-separated) in your shell rc.
The plugin then defines a same-named shell function for each that routes it
through `warp-run`, so you keep typing the command as usual:

```sh
export WARP_HOST=your-internal-host
export WARP_WRAP_CMDS="tea glab"
source ~/.local/bin/git-warp.plugin.sh
```

Now `tea pr create ...` / `glab mr create ...` auto-connect WARP just like git
does. `WARP_WRAP_CMDS` is empty by default — nothing extra is wrapped unless you
opt in.

## Configuration

| Env var | Default | Meaning |
|---|---|---|
| `GIT_WARP_HOST` | host of `origin` remote | git-warp target host to probe / route through WARP |
| `GIT_WARP_PORT` | `443` | Port to probe for reachability |
| `GIT_WARP_WAIT` | `40` | Seconds to wait for WARP to make the host reachable |
| `WARP_HOST` | none (falls back to `GIT_WARP_HOST`) | warp-run target host; if neither is set, warp-run errors out |
| `WARP_PORT` | `443` (falls back to `GIT_WARP_PORT`) | Port warp-run probes |
| `WARP_WAIT` | `40` (falls back to `GIT_WARP_WAIT`) | Seconds warp-run waits for WARP |
| `WARP_WRAP_CMDS` | empty | Extra command names to wrap transparently (space-separated, e.g. `"tea glab"`), routed through `warp-run` |

Host resolution order: `GIT_WARP_HOST` wins; for `clone` the host is parsed
from the clone URL on the command line (there's no `origin` yet); otherwise the
host is parsed from `git remote get-url origin`. If you push to a remote other
than `origin` and its host differs, set `GIT_WARP_HOST` explicitly.

## Behavior notes

- **Already reachable → WARP untouched.** If the host answers without WARP,
  git-warp won't connect or disconnect anything.
- **State is restored via `trap`.** Even if git fails or you Ctrl-C, WARP returns
  to how it was on entry: off stays off, on stays on.
- It never disconnects a WARP session it didn't open.
- **Transparent mode only wraps network subcommands.** The `git()` shell
  function routes `push`/`pull`/`fetch`/`clone`/`ls-remote`/`remote update`
  through `git-warp` and passes everything else straight to the real git. It
  uses `command git` internally to avoid recursing into itself.

## Requirements

- [`warp-cli`](https://developers.cloudflare.com/warp-client/get-started/) — the Cloudflare WARP client
- `nc` (netcat) — for the reachability probe
- `git`

## License

MIT
