# git-warp

让只能通过 Cloudflare WARP 访问的内网 git 远端，照常用 `git push` / `git pull` / `git clone` 就能用——远端不通时自动开 WARP 穿墙，跑完再自动恢复 WARP 原状。可达的远端（如 github.com）完全不受影响。

![git-warp 工作示意](assets/git-warp.png)

> 正常 push → 撞上内网服务器墙 → WARP 自动 ON 打隧道穿墙 → push 成功 → WARP 自动 OFF 恢复原状。

English version: [README.en.md](README.en.md)

## 安装

```sh
curl -fsSL https://raw.githubusercontent.com/pw-OpenCapsule/git-warp/main/install.sh | sh
```

作为 agent skill（Claude Code / Cursor / Codex / Gemini CLI）：

```sh
npx skills add pw-OpenCapsule/git-warp -y -g
```

## 用法（透明模式，推荐）

把这行加到 `~/.zshrc` 或 `~/.bashrc`（安装脚本会打印这行；也可重跑安装脚本加 `--activate` 自动追加）：

```sh
source ~/.local/bin/git-warp.plugin.sh
```

然后照常用 git 就行，内网远端会自动走 WARP：

```sh
git push
git pull
git fetch --all
git clone https://your-internal-host/group/repo.git
```

只拦截网络子命令（`push` / `pull` / `fetch` / `clone` / `ls-remote` / `remote update`），其余子命令（`commit` / `status` / `add` / `log` …）原样直通真实 git，零延迟、零行为变化。

### 备选：不想改 shell

直接调 `git-warp`，参数和 `git` 完全一样：

```sh
git-warp push origin main
git-warp clone https://your-internal-host/group/repo.git
```

## 配置

| 环境变量 | 默认值 | 含义 |
|---|---|---|
| `GIT_WARP_HOST` | `clone` 时取 clone URL 的 host，否则取 `origin` 远端的 host | 探测 / 走 WARP 的目标主机 |
| `GIT_WARP_PORT` | `443` | 探测可达性的端口 |
| `GIT_WARP_WAIT` | `40` | 等 WARP 把主机变可达的秒数 |

## 说明

- 远端已可达 → 完全不碰 WARP。
- 用 `trap` 恢复 WARP：进入时是关的就关回去，是开的就保持开；即使 git 失败或 Ctrl-C 也会恢复。
- 绝不断开不是自己开的 WARP 会话。

## 依赖

[`warp-cli`](https://developers.cloudflare.com/warp-client/get-started/)、`nc`（netcat）、`git`。

## License

MIT
