#!/bin/sh
#
# install.sh — install sg-git-setup and point git at the company git's public
# entry. Also removes the old git-warp transparent mode if it was installed.
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

# Remove the old git-warp transparent mode: its `git` shell function would
# still try to bring WARP up for `git clone https://sg-git.pwtk.cc/...`.
for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
  if [ ! -f "$rc" ] || ! grep -q 'git-warp' "$rc"; then continue; fi
  cp "$rc" "$rc.bak-git-warp"
  grep -v -e '# git-warp transparent mode' -e 'git-warp.plugin.sh' "$rc.bak-git-warp" > "$rc"
  echo "✓ 已从 $rc 移除旧的 git-warp 透明模式（备份 $rc.bak-git-warp），重开终端生效"
done
for old in git-warp warp-run git-warp.plugin.sh; do
  if [ -e "$BINDIR/$old" ]; then
    rm -f "$BINDIR/$old"
    echo "✓ 已删除旧文件 $BINDIR/$old"
  fi
done

echo ""
# stdin is the curl pipe; give git a terminal in case it has to ask for the password
if (exec </dev/tty) 2>/dev/null; then
  "$TARGET" "$@" < /dev/tty
else
  "$TARGET" "$@"
fi
