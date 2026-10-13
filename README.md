# sg-git-setup

公司 git（Gogs）有一个公网入口 `sg-git-src.pwtk.cc`。它和 `sg-git.pwtk.cc`（旧名 `sg-git.port888.com`）是同一台服务器，账号也一样，不需要 WARP、VPN 或代理就能访问。

这个工具只改 git 的全局配置，仓库一个都不用动。配置后，访问旧地址会自动换成新地址，`pull`、`push`、`clone` 照常用。

English: [README.en.md](README.en.md)

## 安装

在任意一个公司仓库目录里运行：

```sh
curl -fsSL https://raw.githubusercontent.com/pw-OpenCapsule/sg-git-setup/main/install.sh | sh
```

运行一次就够，之后照常用 git，不用改仓库，也不用重开终端。它会做这几件事：

1. **改写地址**：`https://sg-git.pwtk.cc/`、`https://sg-git.port888.com/`，以及 `git@sg-git.pwtk.cc:` 这种写法，都换成 `https://sg-git-src.pwtk.cc/`。之前装过旧版、改写到 `sg-cy-git.caminonode.com` 的，重跑一次会自动换过来。同时删掉以前为了连内网配的 `http.https://sg-git.pwtk.cc/.proxy`。
2. **测试登录**：如果以前存过 sg-git 的账号密码（钥匙串、`store` 等都可以），复制给新域名，然后实际登录一次 sg-cy-git 确认账号能用。没存过或者登录失败，会在终端里问用户名和密码，最多试 3 次，成功后保存，以后 pull / push 不用再输。
3. **退役 git-warp**（登录成功后才做）：从 `~/.zshrc` / `~/.bashrc` / `~/.profile` 去掉透明模式（原文件备份为 `*.bak-git-warp`）。`git-warp`、`warp-run` 换成直接调用 git 的壳，已经打开的终端也照常能用。
4. **卸载 Cloudflare WARP**（登录成功后才做）：先断开，再用 WARP 自带的卸载脚本卸载，需要输入电脑开机密码（sudo）。不想卸载就加 `--keep-warp`：

   ```sh
   curl -fsSL https://raw.githubusercontent.com/pw-OpenCapsule/sg-git-setup/main/install.sh | sh -s -- --keep-warp
   ```

   公司策略锁定了 WARP 时可能卸载不掉，脚本会提示手动卸载的命令。

如果在公司仓库目录里运行，还会用这个仓库实际跑一次 `git ls-remote`。

## 之后

```sh
sg-git-setup                 # 重新配置、测试登录（比如改了密码之后）
sg-git-setup --keep-warp     # 不卸载 WARP
sg-git-setup --undo          # 撤销改写规则
```

网页请用 https://sg-git-src.pwtk.cc 打开（`sg-git.pwtk.cc` 只有内网能打开）。

## 以前的 git-warp

这个仓库原来叫 git-warp，做法是连内网时自动开关 Cloudflare WARP。现在有了公网入口，已经不需要它了。代码保留在 [legacy/](legacy/)，不再维护。
