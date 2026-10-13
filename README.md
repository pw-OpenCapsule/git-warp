# sg-git-setup

公司 git（Gogs）有一个公网入口 `sg-cy-git.caminonode.com`。它和 `sg-git.pwtk.cc`（旧名 `sg-git.port888.com`）是同一台服务器，账号也一样，不需要 WARP、VPN 或代理就能访问。

这个工具只改 git 的全局配置，仓库一个都不用动。配置后，访问旧地址会自动换成新地址，`pull`、`push`、`clone` 照常用。

English: [README.en.md](README.en.md)

## 安装

在任意一个公司仓库目录里运行：

```sh
curl -fsSL https://raw.githubusercontent.com/pw-OpenCapsule/sg-git-setup/main/install.sh | sh
```

它会做这几件事：

1. 把 `sg-git-setup` 装到 `~/.local/bin`。
2. 加一条 git 改写规则：`https://sg-git.pwtk.cc/`、`https://sg-git.port888.com/`，以及 `git@sg-git.pwtk.cc:` 这种写法，都会换成 `https://sg-cy-git.caminonode.com/`。
3. 删掉以前为了连内网配的 `http.https://sg-git.pwtk.cc/.proxy`。
4. 如果以前存过 sg-git 的账号密码（钥匙串、`store` 等 credential helper 都可以），复制一份给新域名，不用再输一次。
5. 用当前仓库跑一次 `git ls-remote` 验证。没存过账号的话，git 会提示输入，输对后自动保存。
6. 如果装过旧的 git-warp，会把它的透明模式从 `~/.zshrc` / `~/.bashrc` / `~/.profile` 里移除（原文件备份为 `*.bak-git-warp`），并删掉 `git-warp`、`warp-run` 两个旧命令。

## 之后

```sh
sg-git-setup                 # 重新配置、验证（比如改了密码之后）
sg-git-setup <仓库地址>       # 用指定仓库验证
sg-git-setup --undo          # 撤销改写规则
```

网页也请改用 https://sg-cy-git.caminonode.com 。

## 以前的 git-warp

这个仓库原来叫 git-warp，做法是连内网时自动开关 Cloudflare WARP。现在有了公网入口，已经不需要它了。代码保留在 [legacy/](legacy/)，不再维护。
