#!/bin/sh
#
# sg-git-setup — reach the company git (Gogs) through its public Cloudflare
# entry instead of WARP. sg-git.pwtk.cc / sg-git.port888.com and
# sg-cy-git.caminonode.com are the same server with the same accounts.
#
# No repo needs changing: a global `url.<new>.insteadOf <old>` rule rewrites
# the old https:// and git@host: remotes on every fetch / pull / push / clone.
#
#   sg-git-setup               configure, check the login, retire git-warp, uninstall WARP
#   sg-git-setup --keep-warp   same, but leave Cloudflare WARP installed
#   sg-git-setup --undo        remove the rewrite rules
#
set -eu

NEW_HOST=sg-cy-git.caminonode.com
NEW=https://$NEW_HOST/
OLD_HOSTS="sg-git.pwtk.cc sg-git.port888.com"

KEEP_WARP=0
UNDO=0
for arg in "$@"; do
  case "$arg" in
    --keep-warp) KEEP_WARP=1 ;;
    --undo) UNDO=1 ;;
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  esac
done

has_tty() { (exec </dev/tty) 2>/dev/null; }

clear_rules() {
  git config --global --unset-all "url.$NEW.insteadOf" 2>/dev/null || true
  # old port888 -> pwtk rewrite; git rewrites only once, so it would not chain
  git config --global --unset-all "url.https://sg-git.pwtk.cc/.insteadOf" 2>/dev/null || true
}

if [ "$UNDO" = 1 ]; then
  clear_rules
  echo "已撤销 $NEW_HOST 的改写规则"
  exit 0
fi

# ---- 1. 改写规则 -----------------------------------------------------------
clear_rules
for h in $OLD_HOSTS; do
  git config --global --add "url.$NEW.insteadOf" "https://$h/"
  git config --global --add "url.$NEW.insteadOf" "git@$h:"
  # 以前为了连内网配的代理，不再需要
  git config --global --unset-all "http.https://$h/.proxy" 2>/dev/null || true
done
echo "✓ 已把 $OLD_HOSTS 改写到 ${NEW_HOST}（仓库不用改）"

# ---- 2. 账号：复用已存的，测试能否登录，不行就问 ------------------------------
cred_get() {
  # cred_get <host> <field>; never prompts
  printf 'protocol=https\nhost=%s\n\n' "$1" \
    | GIT_TERMINAL_PROMPT=0 git credential fill 2>/dev/null | sed -n "s/^$2=//p"
}

login_ok() {
  # login_ok <user> <password>: Gogs web login answers 302 on success, 200 on failure
  _hdr=$(curl -s -m 20 -D - -o /dev/null "${NEW}user/login") || return 2
  _ck=$(printf '%s\n' "$_hdr" | tr -d '\r' | sed -n 's/^[Ss]et-[Cc]ookie: \([^;]*\);.*/\1/p' | paste -sd';' -)
  _csrf=$(printf '%s\n' "$_ck" | tr ';' '\n' | sed -n 's/^_csrf=//p')
  _code=$(printf '%s' "$2" | curl -s -m 20 -o /dev/null -w '%{http_code}' \
    -H "Cookie: $_ck" --data-urlencode "_csrf=$_csrf" \
    --data-urlencode "user_name=$1" --data-urlencode "password@-" "${NEW}user/login") || return 2
  [ "$_code" = 302 ]
}

store_cred() {
  printf 'protocol=https\nhost=%s\nusername=%s\npassword=%s\n\n' "$NEW_HOST" "$1" "$2" \
    | git credential approve 2>/dev/null || true
}

user=$(cred_get "$NEW_HOST" username)
pass=$(cred_get "$NEW_HOST" password)
if [ -z "$pass" ]; then
  for h in $OLD_HOSTS; do
    pass=$(cred_get "$h" password)
    if [ -n "$pass" ]; then
      user=$(cred_get "$h" username)
      echo "✓ 找到 $h 保存的账号 $user"
      break
    fi
  done
fi

LOGIN=0
if [ -n "$pass" ] && login_ok "$user" "$pass"; then
  LOGIN=1
elif has_tty; then
  [ -n "$pass" ] && echo "✗ 已保存的账号 $user 登录 $NEW_HOST 失败，请重新输入"
  for _ in 1 2 3; do
    printf '公司 git 用户名%s: ' "${user:+ [$user]}" >/dev/tty
    read -r input </dev/tty || true
    [ -n "$input" ] && user=$input
    printf '密码: ' >/dev/tty
    stty -echo </dev/tty; read -r pass </dev/tty || true; stty echo </dev/tty
    echo >/dev/tty
    if login_ok "$user" "$pass"; then LOGIN=1; break; fi
    echo "✗ 用户名或密码不对，再试一次" >/dev/tty
  done
fi

if [ "$LOGIN" = 1 ]; then
  store_cred "$user" "$pass"
  echo "✓ 账号 $user 可以登录 ${NEW_HOST}，已保存，pull / push 不用再输密码"
else
  echo "✗ 没能用账号登录 ${NEW_HOST}。在终端里重新运行 sg-git-setup 输入账号密码" >&2
  echo "  （网页 ${NEW} 能登录才说明账号是对的）" >&2
fi

# 在公司仓库里运行时，顺便用这个仓库实测一次
repo=$(git remote get-url origin 2>/dev/null || true)
[ "$LOGIN" = 1 ] || repo=""
case "$repo" in
  *"$NEW_HOST"*)
    if GIT_TERMINAL_PROMPT=0 git ls-remote "$repo" >/dev/null 2>&1; then
      echo "✓ 当前仓库 $repo 可以访问"
    else
      echo "✗ 当前仓库 $repo 访问失败（账号没有这个仓库的权限？）" >&2
    fi ;;
esac

# ---- 3. 退役 git-warp：已开着的终端照常能用 ----------------------------------
# 已经打开的终端里还留着 git-warp 的 `git` 函数，它会调用 git-warp / warp-run。
# 把这两个命令换成直接转给真实命令的壳，旧终端不报错；新终端不再加载。
if [ "$LOGIN" = 1 ]; then
  for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
    if [ ! -f "$rc" ] || ! grep -q 'git-warp' "$rc"; then continue; fi
    cp "$rc" "$rc.bak-git-warp"
    grep -v -e '# git-warp transparent mode' -e 'git-warp.plugin.sh' "$rc.bak-git-warp" > "$rc" || true
    echo "✓ 已从 $rc 移除 git-warp 透明模式（备份 $rc.bak-git-warp）"
  done
  for dir in "$HOME/.local/bin" /usr/local/bin "$(dirname "$(command -v git-warp 2>/dev/null || echo /nonexistent/x)")"; do
    [ -w "$dir" ] || continue
    if [ -f "$dir/git-warp" ] && ! grep -q 'retired by sg-git-setup' "$dir/git-warp"; then
      cat > "$dir/git-warp" <<'EOF'
#!/bin/sh
# git-warp retired by sg-git-setup: git now reaches the company host directly.
if [ "${1:-}" = batch ]; then
  shift
  while [ $# -gt 0 ] && [ "$1" != -- ]; do shift; done
  [ "${1:-}" = -- ] && shift
  exec "$@"
fi
exec git "$@"
EOF
      chmod +x "$dir/git-warp"
      echo "✓ $dir/git-warp 已改为直接调用 git"
    fi
    if [ -f "$dir/warp-run" ] && ! grep -q 'retired by sg-git-setup' "$dir/warp-run"; then
      printf '#!/bin/sh\n# warp-run retired by sg-git-setup\nexec "$@"\n' > "$dir/warp-run"
      chmod +x "$dir/warp-run"
    fi
    if [ -f "$dir/git-warp.plugin.sh" ] && ! grep -q 'retired by sg-git-setup' "$dir/git-warp.plugin.sh"; then
      printf '# git-warp retired by sg-git-setup; sourcing this is a no-op\n' > "$dir/git-warp.plugin.sh"
    fi
  done
fi

# ---- 4. 卸载 Cloudflare WARP（确认新入口能登录之后才动） -----------------------
WARP_APP="/Applications/Cloudflare WARP.app"
warp_installed() { [ -d "$WARP_APP" ] || command -v warp-cli >/dev/null 2>&1; }

if [ "$KEEP_WARP" = 1 ] || ! warp_installed; then
  :
elif [ "$LOGIN" != 1 ]; then
  echo "· 新入口还没登录成功，先不卸载 WARP（以免两边都连不上）"
else
  WARP_CLI=$(command -v warp-cli 2>/dev/null || echo "$WARP_APP/Contents/Resources/warp-cli")
  "$WARP_CLI" disconnect >/dev/null 2>&1 || true
  echo "✓ 已断开 Cloudflare WARP"
  if [ -x "$WARP_APP/Contents/Resources/uninstall.sh" ]; then
    UNINSTALL="\"$WARP_APP/Contents/Resources/uninstall.sh\""
  elif command -v apt-get >/dev/null 2>&1; then
    UNINSTALL="apt-get remove -y cloudflare-warp"
  elif command -v dnf >/dev/null 2>&1; then
    UNINSTALL="dnf remove -y cloudflare-warp"
  else
    UNINSTALL=""
  fi
  if [ -z "$UNINSTALL" ]; then
    echo "· 没找到 WARP 的卸载方式，请手动卸载 Cloudflare WARP"
  elif has_tty; then
    echo "卸载 Cloudflare WARP 需要电脑的开机密码（sudo）："
    if sudo sh -c "$UNINSTALL" </dev/tty >/dev/null 2>&1; then
      echo "✓ 已卸载 Cloudflare WARP"
    else
      echo "✗ WARP 没卸载成功（可能被公司策略锁定），可手动运行：sudo $UNINSTALL" >&2
    fi
  else
    echo "· 要卸载 WARP，请在终端运行：sudo $UNINSTALL"
  fi
fi

[ "$LOGIN" = 1 ] || exit 1
echo ""
echo "完成：照常 git pull / push 即可，网页请用 ${NEW}"
