#!/bin/sh
#
# install.sh — install git-warp into your PATH.
#
#   curl -fsSL https://raw.githubusercontent.com/pw-OpenCapsule/git-warp/main/install.sh | sh
#
# Downloads git-warp.sh and installs it as `git-warp`. By default it goes to
# ~/.local/bin (no sudo). Override the target with BINDIR, e.g.:
#
#   curl -fsSL .../install.sh | BINDIR=/usr/local/bin sh
#
set -eu

RAW_URL="https://raw.githubusercontent.com/pw-OpenCapsule/git-warp/main/git-warp.sh"
BINDIR="${BINDIR:-$HOME/.local/bin}"
TARGET="$BINDIR/git-warp"

mkdir -p "$BINDIR"

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$RAW_URL" -o "$TARGET"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$TARGET" "$RAW_URL"
else
  echo "install: need curl or wget" >&2
  exit 1
fi

chmod +x "$TARGET"
echo "git-warp installed to $TARGET"

case ":$PATH:" in
  *":$BINDIR:"*) ;;
  *) echo "note: $BINDIR is not on your PATH — add it, e.g.:"
     echo "      export PATH=\"$BINDIR:\$PATH\"" ;;
esac

echo "try: git-warp --version   (any git args are passed through)"
