#!/bin/sh
#
# install.sh — install sg-git-setup and run it: point git at the company git's
# public entry, check the login, retire git-warp, uninstall Cloudflare WARP.
# Pass --keep-warp to leave WARP installed:  ... | sh -s -- --keep-warp
#
#   curl -fsSL https://raw.githubusercontent.com/pw-OpenCapsule/sg-git-setup/main/install.sh | sh
#
# Installs to ~/.local/bin by default; override with BINDIR=/some/dir.
# Run it inside any company repo and it also verifies access with that repo.
#
set -eu

RAW_BASE="https://raw.githubusercontent.com/pw-OpenCapsule/sg-git-setup/main"
BINDIR="${BINDIR:-$HOME/.local/bin}"
TARGET="$BINDIR/sg-git-setup"

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

fetch "$RAW_BASE/sg-git-setup.sh" "$TARGET"
chmod +x "$TARGET"
echo "sg-git-setup installed to $TARGET"

echo ""
# stdin is the curl pipe; give git a terminal in case it has to ask for the password
if (exec </dev/tty) 2>/dev/null; then
  "$TARGET" "$@" < /dev/tty
else
  "$TARGET" "$@"
fi
