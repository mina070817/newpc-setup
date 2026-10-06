# Ubuntu 20.04 安装 Codex CLI 并接入 DeepSeek

代理：
```
https://liangxin.xyz/api/v1/liangxin?OwO=4db5733dd040467a61dd3904cd70ebe7
```
## 一、安装 Codex CLI

官方推荐直接用 Linux 安装脚本，不需要先折腾 npm / Node.js。

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

安装输出示例：

```text
==> Installing Codex CLI
==> Detected platform: Linux (x64)
==> Resolved version: 0.155.1
==> Downloading Codex CLI
==> Installing standalone package to /home/zzy/.codex/packages/standalone/releases/0.155.1-x86_64-unknown-linux-musl
==> Current terminal: export PATH="/home/zzy/.local/bin:$PATH" && codex
==> Future terminals: open a new terminal and run: codex
==> PATH was added to /home/zzy/.bashrc
Codex CLI 0.155.1 installed successfully.
```

安装本身是成功的，但**当前 shell 不会自动重新加载 `.bashrc`**，所以直接跑 `codex` 会报：

```text
Command 'codex' not found
```

---

## 二、确认安装位置和软链接

检查实际安装目录：

```bash
ls -la ~/.codex/packages/standalone/releases/0.155.1-x86_64-unknown-linux-musl/
```

输出：

```text
drwxr-xr-x 2 zzy zzy 4096 9月  19 03:25 bin
lrwxrwxrwx 1 zzy zzy    9 9月  22 13:46 codex -> bin/codex
-rw-r--r-- 1 zzy zzy  205 9月  19 03:25 codex-package.json
drwxr-xr-x 2 zzy zzy 4096 9月  19 03:25 codex-path
drwxr-xr-x 4 zzy zzy 4096 9月  19 03:25 codex-resources
```

检查 `~/.local/bin`：

```bash
ls -la ~/.local/bin/
```

输出：

```text
lrwxrwxrwx 1 zzy zzy   54 9月  22 13:46 codex -> /home/zzy/.codex/packages/standalone/current/bin/codex
```

检查 `current` 软链接：

```bash
ls -la ~/.codex/packages/standalone/
```

输出：

```text
lrwxrwxrwx 1 zzy zzy   79 9月  22 13:46 current -> /home/zzy/.codex/packages/standalone/releases/0.155.1-x86_64-unknown-linux-musl
```

结论：安装、软链接链路全部正常，唯一问题是 PATH。

---

## 三、解决 `codex: command not found`

检查 `.bashrc` 是否写入了 PATH：

```bash
grep -n 'local/bin\|\.codex' ~/.bashrc
```

输出：

```text
120:export PATH="/home/zzy/.local/bin:$PATH"
```

说明安装脚本已经写进去了，只是当前 shell 没重载。

重新加载 `.bashrc`：

```bash
source ~/.bashrc
```

验证：

```bash
which codex
codex --version
```

输出：

```text
/home/zzy/.local/bin/codex
codex-cli 0.155.1
```

成功。

> 以后新开终端会自动加载 `.bashrc`，不用再手动 `source`。
>
> 如果某些机器上 `.bashrc` 里有 ROS 环境选择脚本（如 `ros:foxy(1) noetic(2)...`），选完对应编号后 PATH 就会继续生效。

---

## 四、把 Codex 接入 DeepSeek

DeepSeek 官方提供了配置脚本，会自动写入 Codex 配置并备份原配置。

```bash
bash <(curl -fsSL https://cdn.deepseek.com/api-docs/codex-deepseek-setup-en.sh)
```

运行后出现菜单：

```text
Codex DeepSeek Setup  v1.3.0
Codex directory: /home/zzy/.codex

Choose an action:
  1. Configure Codex to use the deepseek-flash model
  2. Configure Codex to use the deepseek-v4-pro model
  3. Restore the default Codex configuration (remove deepseek settings)

Enter 1 / 2 / 9:
```

选 **1**（`deepseek-flash`，最便宜、响应快，日常写代码够用）。

然后按提示输入 DeepSeek API Key（`sk-` 开头，在 DeepSeek 平台申请）。

---

## 五、验证接入成功

启动 Codex：

```bash
codex
```

横幅里显示：

```text
model: deepseek-flash high
```

说明已经成功接入 DeepSeek，不再使用默认 GPT 模型。

---

## 六、模型价格参考

| 模型 | 输入（缓存命中） | 输入（缓存未命中） | 输出 |
|------|------|------|------|
| **deepseek-flash** | 0.5 元 | 1.25 元 | 2.5 元 |
| **deepseek-v4-pro** | 1.5 元 | 15 元 | 30 元 |

`deepseek-flash` 输出价格只有 `pro` 的 1/12，日常编码足够。

如果想切换模型，在 Codex 交互界面输入：

```text
/model
```

---

## 七、常见问题

### 1. `codex: command not found`

原因：当前 shell 没重新加载 `.bashrc`。

解决：

```bash
source ~/.bashrc
codex --version
```

**不要**执行 `sudo snap install codex`，那是 Ubuntu 的同名 snap 包，跟 OpenAI Codex CLI 不是一回事，会冲突。

### 2. 代理与 DeepSeek

如果环境里有：

```bash
https_proxy=http://127.0.0.1:7897
http_proxy=http://127.0.0.1:7897
all_proxy=socks5://127.0.0.1:7897
```

`api.deepseek.com` 国内可直连，若发现响应慢，可临时清掉代理：

```bash
unset https_proxy http_proxy all_proxy
codex
```

或在 Clash/Mihomo 里给 `api.deepseek.com` 配直连规则。

### 3. 自动更新

`~/.codex/packages/standalone/auto-update-version` 说明 Codex 支持自动更新，升级后会新建 `releases/<新版本>/` 并更新 `current` 软链接，`~/.local/bin/codex` 会间接指向新版本，无需重建软链接。

---

## 最终结果

```text
which codex        → /home/zzy/.local/bin/codex
codex --version    → codex-cli 0.155.1
codex 横幅         → model: deepseek-flash high
```

Codex CLI 安装成功，PATH 正常，已接入 DeepSeek。