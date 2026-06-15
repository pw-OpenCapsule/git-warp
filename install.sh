#!/bin/sh
#
# install.sh — install git-warp into your PATH.
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
# Transparent mode: source the installed git-warp.plugin.sh from your shell rc
# to make plain `git push` / `git pull` / `git clone <url>` auto-route through
# WARP for unreachable remotes. This installer does NOT edit your rc file; it
# prints the line to add. Pass --activate to have it append that line to your
# rc file for you:
#
#   curl -fsSL .../install.sh | sh -s -- --activate
#
set -eu

ACTIVATE=0
for arg in "$@"; do
  case "$arg" in
    --activate) ACTIVATE=1 ;;
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

# Pick the most likely rc file for the activation hint / append.
case "${SHELL:-}" in
  *zsh) RC="$HOME/.zshrc" ;;
  *bash) RC="$HOME/.bashrc" ;;
  *) RC="$HOME/.zshrc" ;;
esac

if [ "$ACTIVATE" -eq 1 ]; then
  if [ -f "$RC" ] && grep -qF "$PLUGIN" "$RC" 2>/dev/null; then
    echo "transparent mode already enabled in $RC"
  else
    printf '\n# git-warp transparent mode\n%s\n' "$SOURCE_LINE" >> "$RC"
    echo "transparent mode enabled: appended to $RC"
    echo "restart your shell or run: $SOURCE_LINE"
  fi
else
  echo ""
  echo "To enable transparent mode (plain 'git push'/'git pull'/'git clone' auto-route"
  echo "through WARP for unreachable remotes), add this line to your ~/.zshrc or ~/.bashrc:"
  echo ""
  echo "    $SOURCE_LINE"
  echo ""
  echo "(or re-run this installer with --activate to append it for you)"
fi

echo "try: git-warp --version   (any git args are passed through)"
