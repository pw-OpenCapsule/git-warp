#!/bin/sh
#
# install.sh — install git-warp into your PATH and activate transparent mode.
#
#   curl -fsSL https://raw.githubusercontent.com/pw-OpenCapsule/git-warp/main/install.sh | sh
#
# Downloads git-warp.sh (installed as `git-warp`), warp-run.sh (installed as
# `warp-run`, the generic any-command wrapper) and git-warp.plugin.sh (the
# transparent-mode shell wrapper). By default they go to ~/.local/bin (no
# sudo). Override the target with BINDIR, e.g.:
#
#   curl -fsSL .../install.sh | BINDIR=/usr/local/bin sh
#
# Transparent mode is activated by default: the installer appends a
# `source <plugin>` line to your shell rc (~/.zshrc / ~/.bashrc / ~/.profile,
# picked from $SHELL) so plain `git push` / `git pull` / `git clone <url>`
# auto-route through WARP for unreachable remotes. The append is idempotent —
# re-running won't duplicate the line. To skip it (don't touch your rc), pass
# --no-activate or set GIT_WARP_NO_ACTIVATE=1:
#
#   curl -fsSL .../install.sh | sh -s -- --no-activate
#   curl -fsSL .../install.sh | GIT_WARP_NO_ACTIVATE=1 sh
#
set -eu

# Default: activate. --no-activate (or GIT_WARP_NO_ACTIVATE=1) opts out.
ACTIVATE=1
if [ "${GIT_WARP_NO_ACTIVATE:-}" = "1" ]; then
  ACTIVATE=0
fi
for arg in "$@"; do
  case "$arg" in
    --no-activate) ACTIVATE=0 ;;
    --activate)    ACTIVATE=1 ;;
  esac
done

RAW_BASE="https://raw.githubusercontent.com/pw-OpenCapsule/git-warp/main"
BINDIR="${BINDIR:-$HOME/.local/bin}"
TARGET="$BINDIR/git-warp"
WARPRUN="$BINDIR/warp-run"
PLUGIN="$BINDIR/git-warp.plugin.sh"

mkdir -p "$BINDIR"

fetch() {
  # fetch <url> <dest>
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "$1"
  else
    echo "install: need curl or wget" >&2
    exit 1
  fi
}

fetch "$RAW_BASE/git-warp.sh" "$TARGET"
chmod +x "$TARGET"
echo "git-warp installed to $TARGET"

fetch "$RAW_BASE/warp-run.sh" "$WARPRUN"
chmod +x "$WARPRUN"
echo "warp-run installed to $WARPRUN"

fetch "$RAW_BASE/git-warp.plugin.sh" "$PLUGIN"
echo "transparent-mode wrapper installed to $PLUGIN"

case ":$PATH:" in
  *":$BINDIR:"*) ;;
  *) echo "note: $BINDIR is not on your PATH — add it, e.g.:"
     echo "      export PATH=\"$BINDIR:\$PATH\"" ;;
esac

SOURCE_LINE="source \"$PLUGIN\""
MARKER="# git-warp transparent mode"

# Pick the shell rc to activate in, based on $SHELL.
case "${SHELL:-}" in
  *zsh)  RC="$HOME/.zshrc" ;;
  *bash) RC="$HOME/.bashrc" ;;
  *)     RC="$HOME/.profile" ;;
esac

if [ "$ACTIVATE" -eq 1 ]; then
  # Idempotent: skip if the plugin path (or our marker) is already in the rc.
  if [ -f "$RC" ] && grep -qF "$PLUGIN" "$RC" 2>/dev/null; then
    echo "✓ 透明模式已激活（${RC} 已包含 git-warp，跳过）。"
  else
    # Create the rc if missing, then append the source line with a marker.
    [ -f "$RC" ] || : > "$RC"
    printf '\n%s\n%s\n' "$MARKER" "$SOURCE_LINE" >> "$RC"
    echo "✓ 已激活透明模式（写入 ${RC}）。重启终端，或运行 ${SOURCE_LINE} 立即生效。"
  fi
else
  echo ""
  echo "跳过自动激活（--no-activate）。要启用透明模式（让 'git push' / 'git pull' /"
  echo "'git clone' 在远端不通时自动走 WARP），把这行加到你的 shell rc："
  echo ""
  echo "    $SOURCE_LINE"
  echo ""
fi

echo ""
echo "完成。确认安装：git-warp --help  （任意 git 参数都会透传）"
echo "重开终端后，照常 git push 即自动走 WARP。"
