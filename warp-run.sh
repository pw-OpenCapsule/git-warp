#!/usr/bin/env bash
#
# warp-run.sh — run ANY command against a host that is only reachable through
# Cloudflare WARP.
#
# This is the generic sibling of git-warp: instead of wrapping git, it wraps an
# arbitrary command. If the target host is unreachable it brings WARP up, waits
# until the port is reachable, runs the command, then restores WARP to its
# ENTRY state (disconnects only if WARP was off when we started; leaves it
# connected otherwise). The restore runs from a trap, so WARP is restored even
# if the command fails or the script exits abnormally. If the host is already
# reachable, WARP is not touched at all.
#
# Use it for anything else that needs the internal network — creating a PR with
# a CLI (tea / glab), calling an internal API with curl, etc.
#
# Usage:  warp-run tea pr create --base main --head feature ...
#         warp-run glab mr create ...
#         warp-run curl https://internal-host/api/...
# The command and its arguments are passed through unchanged.
# Exit code = the wrapped command's exit code, or 2 if WARP could not make the
# host reachable.
#
# Target host resolution (first match wins):
#   1. $WARP_HOST           — explicit override
#   2. $GIT_WARP_HOST       — reuse git-warp's host if set
# (no default — set WARP_HOST or GIT_WARP_HOST)
# Port defaults to 443 ($WARP_PORT, falls back to $GIT_WARP_PORT).
# Wait timeout defaults to 40s ($WARP_WAIT, falls back to $GIT_WARP_WAIT).

set -uo pipefail

# --- resolve target host -----------------------------------------------------

HOST="${WARP_HOST:-${GIT_WARP_HOST:-}}"
if [ -z "$HOST" ]; then
  echo "warp-run: cannot determine target host — set WARP_HOST (or GIT_WARP_HOST)" >&2
  exit 2
fi

PORT="${WARP_PORT:-${GIT_WARP_PORT:-443}}"
WAIT="${WARP_WAIT:-${GIT_WARP_WAIT:-40}}"

if [ "$#" -eq 0 ]; then
  echo "warp-run: no command given — usage: warp-run <command> [args...]" >&2
  exit 2
fi

# --- reachability ------------------------------------------------------------

# True if the host:port is reachable right now.
reachable() {
  nc -z -G 3 -w 3 "$HOST" "$PORT" >/dev/null 2>&1
}

# Record WARP state on entry: connected (and not disconnected) => 1, else 0.
was_connected=0
warp_status="$(warp-cli status 2>/dev/null || true)"
if printf '%s' "$warp_status" | grep -q 'Connected' \
   && ! printf '%s' "$warp_status" | grep -q 'Disconnected'; then
  was_connected=1
fi

# Restore WARP to its entry state on any exit.
cleanup() {
  if [ "$was_connected" -eq 0 ]; then
    echo "warp-run: restoring WARP to disconnected (was off on entry)" >&2
    warp-cli disconnect >/dev/null 2>&1 || true
  else
    echo "warp-run: leaving WARP connected (was on on entry / already reachable)" >&2
  fi
}
trap cleanup EXIT

# --- run ---------------------------------------------------------------------

# If already reachable, don't touch WARP at all. Treat as was_connected=1 so
# cleanup won't disconnect someone else's WARP (or a path we didn't open).
if reachable; then
  echo "warp-run: $HOST:$PORT already reachable, leaving WARP untouched" >&2
  was_connected=1
else
  echo "warp-run: $HOST:$PORT unreachable, connecting WARP…" >&2
  warp-cli connect >/dev/null 2>&1 || true

  connected=0
  i=0
  while [ "$i" -lt "$WAIT" ]; do
    if reachable; then
      connected=1
      break
    fi
    sleep 1
    i=$((i + 1))
  done

  if [ "$connected" -ne 1 ]; then
    echo "warp-run: $HOST:$PORT still unreachable after ${WAIT}s via WARP" >&2
    exit 2
  fi
  echo "warp-run: $HOST:$PORT reachable, running command" >&2
fi

# Use `command` so that, if a shell wrapper function (e.g. one defined by
# git-warp.plugin.sh for WARP_WRAP_CMDS) leaks into this process somehow, we
# still invoke the real binary and never recurse back into warp-run.
command "$@"
exit $?
