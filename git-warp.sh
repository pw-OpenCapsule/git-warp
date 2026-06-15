#!/usr/bin/env bash
#
# git-warp.sh — run a git command against a remote that is only reachable
# through Cloudflare WARP.
#
# Some git remotes (private/internal servers) only answer when you are
# connected to Cloudflare WARP. This wraps git so you don't have to manage
# WARP by hand: if the remote host is unreachable it brings WARP up, waits
# until the port is reachable, runs git, then restores WARP to its ENTRY
# state (disconnects only if WARP was off when we started; leaves it
# connected otherwise). The restore runs from a trap, so WARP is restored
# even if git fails or the script exits abnormally. If the remote is already
# reachable, WARP is not touched at all.
#
# Usage:  git-warp push origin main
#         git-warp pull
#         git-warp fetch
# Any git arguments are passed through unchanged.
# Exit code = git's exit code, or 2 if WARP could not make the host reachable.
#
# Target host resolution (first match wins):
#   1. $GIT_WARP_HOST            — explicit override
#   2. host of `git remote get-url origin`  — auto-detected from the repo
# Port defaults to 443 ($GIT_WARP_PORT to override).
# Wait timeout defaults to 40s ($GIT_WARP_WAIT, in seconds).

set -uo pipefail

# --- resolve target host -----------------------------------------------------

# Extract the hostname from a git remote URL. Handles both forms:
#   https://host[:port]/path        scp-like: [user@]host:path
url_host() {
  url="$1"
  case "$url" in
    *://*)
      # strip scheme, then optional user@, then take up to first / or :
      rest="${url#*://}"
      rest="${rest#*@}"
      rest="${rest%%/*}"
      printf '%s' "${rest%%:*}"
      ;;
    *@*:*|*:*)
      # scp-like syntax: [user@]host:path
      rest="${url#*@}"
      printf '%s' "${rest%%:*}"
      ;;
    *)
      printf '%s' ""
      ;;
  esac
}

HOST="${GIT_WARP_HOST:-}"
if [ -z "$HOST" ]; then
  origin_url="$(git remote get-url origin 2>/dev/null || true)"
  if [ -n "$origin_url" ]; then
    HOST="$(url_host "$origin_url")"
  fi
fi

if [ -z "$HOST" ]; then
  echo "git-warp: cannot determine target host — set GIT_WARP_HOST or add an 'origin' remote" >&2
  exit 2
fi

PORT="${GIT_WARP_PORT:-443}"
WAIT="${GIT_WARP_WAIT:-40}"

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
    echo "git-warp: restoring WARP to disconnected (was off on entry)" >&2
    warp-cli disconnect >/dev/null 2>&1 || true
  else
    echo "git-warp: leaving WARP connected (was on on entry / already reachable)" >&2
  fi
}
trap cleanup EXIT

# --- run ---------------------------------------------------------------------

# If already reachable, don't touch WARP at all. Treat as was_connected=1 so
# cleanup won't disconnect someone else's WARP (or a path we didn't open).
if reachable; then
  echo "git-warp: $HOST:$PORT already reachable, leaving WARP untouched" >&2
  was_connected=1
else
  echo "git-warp: $HOST:$PORT unreachable, connecting WARP…" >&2
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
    echo "git-warp: $HOST:$PORT still unreachable after ${WAIT}s via WARP" >&2
    exit 2
  fi
  echo "git-warp: $HOST:$PORT reachable, running git" >&2
fi

git "$@"
exit $?
