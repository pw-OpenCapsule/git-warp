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
#   2. for `clone`: host parsed from the clone URL argument (no origin yet)
#   3. for push/pull/fetch/ls-remote: host of the *remote argument* in the
#      command (e.g. `fetch gitlab dev` -> remote `gitlab`), looked up in the
#      repository selected by any leading `git -C <path>` global options;
#      falls back to `origin` when there's no positional remote.
#   4. host of `git [-C ...] remote get-url origin`  — auto-detected.
# Leading git global options are parsed the way git does: repeated `-C <path>`
# is accumulated (and passed through to the inner `git remote` lookups), and
# other valued global options (-c <kv>, --git-dir <d>, --work-tree <d>, …) are
# skipped together with their value so they're not mistaken for the subcommand
# or remote name.
# Host allowlist: WARP is only managed for hosts in $GIT_WARP_ALLOW_HOSTS
# (comma/space-separated, shell-glob patterns; default "sg-git.pwtk.cc"). Any
# other host — or one that can't be determined — is run through plain git with
# WARP left untouched. Set GIT_WARP_ALLOW_HOSTS="*" for the old manage-every-host
# behavior; an explicit $GIT_WARP_HOST always bypasses the allowlist.
# Port defaults to 443 ($GIT_WARP_PORT to override).
# Wait timeout defaults to 40s ($GIT_WARP_WAIT, in seconds).
# Set GIT_WARP_DEBUG=1 to print the resolved host (and remote) and exit without
# touching WARP or git — handy for testing/reproducing host-inference issues.

set -uo pipefail

# --- batch mode --------------------------------------------------------------

# Batch mode keeps WARP in the entry-state-managed scope for a whole command,
# so scripts that invoke git-warp many times do not connect/disconnect WARP for
# every single git command.
if [ "${1:-}" = "batch" ] || [ "${1:-}" = "run" ]; then
  shift
  batch_host="${GIT_WARP_HOST:-}"
  batch_port="${GIT_WARP_PORT:-}"
  batch_wait="${GIT_WARP_WAIT:-}"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --host)
        [ "$#" -ge 2 ] || { echo "git-warp batch: --host requires a value" >&2; exit 2; }
        batch_host="$2"
        shift 2
        ;;
      --host=*)
        batch_host="${1#--host=}"
        shift
        ;;
      --port)
        [ "$#" -ge 2 ] || { echo "git-warp batch: --port requires a value" >&2; exit 2; }
        batch_port="$2"
        shift 2
        ;;
      --port=*)
        batch_port="${1#--port=}"
        shift
        ;;
      --wait)
        [ "$#" -ge 2 ] || { echo "git-warp batch: --wait requires a value" >&2; exit 2; }
        batch_wait="$2"
        shift 2
        ;;
      --wait=*)
        batch_wait="${1#--wait=}"
        shift
        ;;
      --)
        shift
        break
        ;;
      -*)
        echo "git-warp batch: unknown option: $1" >&2
        exit 2
        ;;
      *)
        break
        ;;
    esac
  done

  if [ "$#" -eq 0 ]; then
    echo "git-warp batch: no command given — usage: git-warp batch --host <host> -- <command> [args...]" >&2
    exit 2
  fi
  if [ -z "$batch_host" ]; then
    echo "git-warp batch: cannot determine target host — set --host or GIT_WARP_HOST" >&2
    exit 2
  fi

  script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
  WARP_HOST="$batch_host" \
    WARP_PORT="${batch_port:-${WARP_PORT:-${GIT_WARP_PORT:-443}}}" \
    WARP_WAIT="${batch_wait:-${WARP_WAIT:-${GIT_WARP_WAIT:-40}}}" \
    GIT_WARP_HOST="$batch_host" \
    GIT_WARP_PORT="${batch_port:-${GIT_WARP_PORT:-443}}" \
    GIT_WARP_WAIT="${batch_wait:-${GIT_WARP_WAIT:-40}}" \
    "$script_dir/warp-run" "$@"
  exit $?
fi

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

# Parse the leading git global options (everything before the subcommand) the
# same way git does. Populates two globals:
#   CDIRS   — array of `-C <path>` tokens, in order (passed through to the
#             inner `git remote get-url` lookups so the host is resolved in the
#             repo git itself would operate on; git applies multiple -C
#             cumulatively, so passing them all through reproduces that).
#   SUBCMD  — the git subcommand (first non-option, non-option-value arg).
#   SUBIDX  — 1-based index of SUBCMD within "$@" (0 if none found).
# Valued global options are skipped together with their value so neither the
# value nor a following positional is mistaken for the subcommand.
CDIRS=()
SUBCMD=""
SUBIDX=0
parse_globals() {
  local i=1 a
  while [ "$i" -le "$#" ]; do
    a="${!i}"
    case "$a" in
      -C)
        # -C <path>: accumulate both tokens, advance past the value.
        local j=$((i + 1))
        if [ "$j" -le "$#" ]; then
          CDIRS+=( -C "${!j}" )
          i=$((i + 2))
          continue
        fi
        i=$((i + 1))
        ;;
      -c|--git-dir|--work-tree|--namespace|--super-prefix|--config-env)
        # valued global option in "--opt <val>" form: skip the value too.
        i=$((i + 2))
        ;;
      --git-dir=*|--work-tree=*|--namespace=*|-C=*|--super-prefix=*|--config-env=*|-c=*)
        # valued global option in "--opt=val" form: value is attached.
        i=$((i + 1))
        ;;
      --*|-*)
        # any other leading flag (e.g. -p, --no-pager, --bare, --paginate):
        # boolean global option, skip just this token.
        i=$((i + 1))
        ;;
      *)
        # first non-option, non-option-value argument => the subcommand.
        SUBCMD="$a"
        SUBIDX="$i"
        return 0
        ;;
    esac
  done
  return 0
}
parse_globals "$@"

# For network subcommands that take a remote argument, the remote name is the
# first *positional* argument after the subcommand (skipping flags and the
# values of valued flags). `fetch --all` / no positional remote -> "" (origin).
remote_arg() {
  local i=$((SUBIDX + 1)) a
  [ "$SUBIDX" -gt 0 ] || return 0
  while [ "$i" -le "$#" ]; do
    a="${!i}"
    case "$a" in
      # flags that consume the next token as their value — skip both.
      -o|--upload-pack|--exec|--depth|--deepen|--shallow-since|--shallow-exclude|--refmap|-j|--jobs|--negotiation-tip|--server-option|--recurse-submodules)
        i=$((i + 2))
        ;;
      -*) i=$((i + 1)) ;;             # other flags: skip just this token
      *) printf '%s' "$a"; return 0 ;; # first positional => remote name
    esac
  done
  return 0
}

HOST="${GIT_WARP_HOST:-}"
# Whether the host was set explicitly via GIT_WARP_HOST — an explicit host is
# operator intent and always bypasses the allowlist below.
HOST_EXPLICIT=0
[ -n "$HOST" ] && HOST_EXPLICIT=1
REMOTE=""

# For `clone` there is no origin remote yet, so resolve the host from the
# clone URL on the command line: the first non-flag argument (after the
# `clone` subcommand) that looks like a URL or scp-style path.
if [ -z "$HOST" ] && [ "$SUBCMD" = "clone" ]; then
  i=$((SUBIDX + 1))
  while [ "$i" -le "$#" ]; do
    arg="${!i}"
    i=$((i + 1))
    case "$arg" in
      -*) continue ;;                 # skip flags (-b, --depth, etc.)
      *://*|*@*:*|*:*/*|*:*)          # URL or scp-like [user@]host:path
        HOST="$(url_host "$arg")"
        [ -n "$HOST" ] && break
        ;;
    esac
  done
fi

# For network subcommands, infer the host from the remote *argument* in the
# command (looked up in the -C-selected repo); fall back to origin.
if [ -z "$HOST" ]; then
  case "$SUBCMD" in
    fetch|pull|push|ls-remote) REMOTE="$(remote_arg "$@")" ;;
    remote)                    REMOTE="" ;;   # `remote update` -> origin
  esac

  remote_url=""
  if [ -n "$REMOTE" ]; then
    remote_url="$(command git "${CDIRS[@]}" remote get-url "$REMOTE" 2>/dev/null || true)"
  fi
  # No positional remote, or it didn't resolve (e.g. doesn't exist) -> origin.
  if [ -z "$remote_url" ]; then
    REMOTE="origin"
    remote_url="$(command git "${CDIRS[@]}" remote get-url origin 2>/dev/null || true)"
  fi
  if [ -n "$remote_url" ]; then
    HOST="$(url_host "$remote_url")"
  fi
fi

# --- host allowlist ----------------------------------------------------------
# git-warp only manages WARP for hosts in the allowlist; every other host (or a
# host that couldn't be determined) is run straight through plain git and WARP
# is never touched. This keeps WARP-management scoped to the internal remotes
# that actually need it — public/other remotes (github.com, gitlab.com, …) are
# completely unaffected even when they're unreachable from the current network.
# GIT_WARP_ALLOW_HOSTS is a comma/space-separated list of host patterns (shell
# globs allowed, e.g. "sg-git.pwtk.cc *.pwtk.cc"); it defaults to sg-git.pwtk.cc.
# Set it to "*" to manage WARP for every host (the pre-allowlist behavior).
# An explicit GIT_WARP_HOST always bypasses the allowlist (operator intent).
GIT_WARP_ALLOW_HOSTS="${GIT_WARP_ALLOW_HOSTS:-sg-git.pwtk.cc}"

host_allowed() {
  local h="$1" pat
  [ -n "$h" ] || return 1
  for pat in ${GIT_WARP_ALLOW_HOSTS//,/ }; do
    case "$h" in
      $pat) return 0 ;;
    esac
  done
  return 1
}

allowed=0
if [ "$HOST_EXPLICIT" -eq 1 ] || host_allowed "$HOST"; then
  allowed=1
fi

if [ -n "${GIT_WARP_DEBUG:-}" ]; then
  echo "git-warp: [debug] subcmd=${SUBCMD:-} remote=${REMOTE:-} cdirs=${CDIRS[*]:-} host=${HOST:-} allowed=${allowed} allow_hosts=${GIT_WARP_ALLOW_HOSTS}" >&2
  exit 0
fi

# Not an allowlisted host (or host undeterminable): run plain git, never touch
# WARP. This is the path normal remotes take in transparent mode.
if [ "$allowed" -ne 1 ]; then
  command git "$@"
  exit $?
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

# Use `command git` so that, if a `git()` shell wrapper function from
# git-warp.plugin.sh leaks into this process's environment somehow, we still
# invoke the real git binary and never recurse back into git-warp.
command git "$@"
exit $?
