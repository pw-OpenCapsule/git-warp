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
