# git-warp.plugin.sh — transparent mode for git-warp.
#
# Source this from your ~/.zshrc or ~/.bashrc:
#
#     source /path/to/git-warp.plugin.sh
#
# It defines a `git()` shell function that transparently routes the network
# subcommands (push / pull / fetch / clone / ls-remote, and `remote update`)
# through `git-warp`, so you can keep typing plain `git push` / `git pull` /
# `git clone <url>` and an internal-only remote will auto-connect WARP when
# it's unreachable. Every other git subcommand (commit, status, add, log, …)
# is passed straight through to the real git with zero added behavior or
# latency.
#
# `git-warp` itself only touches WARP when the remote is unreachable, so
# remotes that already answer (e.g. github.com) are completely unaffected.
#
# Requires `git-warp` to be on your PATH (install.sh puts it in ~/.local/bin).
#
# Wrapping other commands: set $WARP_WRAP_CMDS to a space-separated list of
# command names (e.g. export WARP_WRAP_CMDS="tea glab") and this file will
# define a same-named shell function for each that routes it through
# `warp-run` — so `tea pr create ...` auto-connects WARP just like git does.
# Requires `warp-run` on PATH and $WARP_HOST (or $GIT_WARP_HOST) set.
# Default is empty: nothing extra is wrapped unless you opt in.

git() {
  case "$1" in
    push|pull|fetch|clone|ls-remote)
      command git-warp "$@"
      ;;
    remote)
      # only `git remote update` does network I/O; everything else is local
      if [ "$2" = "update" ]; then
        command git-warp "$@"
      else
        command git "$@"
      fi
      ;;
    *)
      command git "$@"
      ;;
  esac
}

# Define a wrapper function for each command name in $WARP_WRAP_CMDS, routing it
# through `warp-run`. The function runs `warp-run <cmd> "$@"`; warp-run invokes
# the real binary with `command` in its own process, so this never recurses.
if [ -n "${WARP_WRAP_CMDS:-}" ]; then
  for _warp_cmd in $WARP_WRAP_CMDS; do
    eval "${_warp_cmd}() { command warp-run ${_warp_cmd} \"\$@\"; }"
  done
  unset _warp_cmd
fi
