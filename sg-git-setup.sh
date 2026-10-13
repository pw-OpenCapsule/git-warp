#!/bin/sh
#
# sg-git-setup — reach the company git (Gogs) through its public Cloudflare
# entry instead of WARP. sg-git.pwtk.cc / sg-git.port888.com and
# sg-cy-git.caminonode.com are the same server with the same accounts.
#
# No repo needs changing: a global `url.<new>.insteadOf <old>` rule rewrites
# the old https:// and git@host: remotes on every fetch / pull / push / clone.
#
#   sg-git-setup [repo-url]   configure, copy saved credentials, verify
#   sg-git-setup --undo       remove the rewrite rules
#
set -eu

NEW_HOST=sg-cy-git.caminonode.com
NEW=https://$NEW_HOST/
OLD_HOSTS="sg-git.pwtk.cc sg-git.port888.com"

clear_rules() {
  git config --global --unset-all "url.$NEW.insteadOf" 2>/dev/null || true
  # 旧的 port888 -> pwtk 改写；git 只改写一次，不会再链到新地址
  git config --global --unset-all "url.https://sg-git.pwtk.cc/.insteadOf" 2>/dev/null || true
}

if [ "${1:-}" = "--undo" ]; then
  clear_rules
  echo "已撤销 $NEW_HOST 的改写规则"
  exit 0
fi

clear_rules
for h in $OLD_HOSTS; do
  git config --global --add "url.$NEW.insteadOf" "https://$h/"
  git config --global --add "url.$NEW.insteadOf" "git@$h:"
  # 以前为了连内网配的代理，不再需要
  git config --global --unset-all "http.https://$h/.proxy" 2>/dev/null || true
done
echo "✓ 已把 $OLD_HOSTS 改写到 $NEW_HOST"

# 把旧域名已保存的账号密码复制给新域名，免得再输一次
if ! printf 'protocol=https\nhost=%s\n\n' "$NEW_HOST" \
    | GIT_TERMINAL_PROMPT=0 git credential fill >/dev/null 2>&1; then
  for h in $OLD_HOSTS; do
    cred=$(printf 'protocol=https\nhost=%s\n\n' "$h" \
      | GIT_TERMINAL_PROMPT=0 git credential fill 2>/dev/null) || continue
    printf '%s\n\n' "$cred" | sed "s/^host=.*/host=$NEW_HOST/" | git credential approve
    echo "✓ 已复用 $h 保存的账号"
    break
  done
fi

# 验证：用一个真实仓库跑 ls-remote（参数给的，或者当前目录的 origin）。
# 账号不对时 git 会提示重新输入，输对后自动保存。
repo=${1:-$(git remote get-url origin 2>/dev/null || true)}
case "$repo" in
  *sg-git.pwtk.cc*|*sg-git.port888.com*|*$NEW_HOST*)
    if git ls-remote "$repo" >/dev/null; then
      echo "✓ $repo 可以访问，pull / push 照常用"
    else
      echo "✗ $repo 访问失败" >&2; exit 1
    fi ;;
  *) echo "提示：在任一公司仓库目录里 git pull 一次即可验证（或 sg-git-setup <仓库地址>）" ;;
esac
