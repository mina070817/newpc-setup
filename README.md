# newpc-setup

把旧 Ubuntu 电脑上攒好的一套日常环境整体打包，方便在一台新电脑上快速复现。
目标是 **Ubuntu + GNOME + x86_64**，脚本同时提供 **20.04** 和 **22.04** 两份。

整个文件夹可以直接拷到新电脑的桌面，交给新电脑上的 Codex 按 `提示词.md` 走，或者自己手动执行。

## 目录结构

```
newpc-setup/
├── 提示词.md                  # 给新电脑上的 Codex 看的完整配置说明（推荐入口）
├── codex安装.md               # Codex CLI 安装 + DeepSeek 接入的踩坑记录
├── 脚本/                      # 各组件的一键安装脚本，每项分 20.04 / 22.04 两份
│   ├── install_zsh_ubuntu2004.sh / install_zsh_ubuntu2204.sh
│   ├── install_sogou_ubuntu2004.sh / install_sogou_ubuntu2204.sh
│   ├── install_redshift_eyecare.sh          # 20.04 / 22.04 通用
│   ├── install_codex_ubuntu2004.sh / install_codex_ubuntu2204.sh
│   ├── install_worklog_hook.sh              # Codex 会话工作日志钩子
│   └── install_reuse_skill.sh               # 安装 reuse-first skill
├── 配置/                      # 从旧电脑带过来的配置文件
│   ├── zshrc                  # 定制 .zshrc，含 __HOME__ 占位符
│   ├── fzf.zsh                # fzf 的 zsh 集成（备用）
│   ├── clash-proxy.sh         # 开终端自动探测 Clash 端口，按需注入/清除代理变量
│   ├── set_proxy_gui.sh       # 图形化把代理写进 /etc/profile.d/proxy.sh
│   ├── work-log.sh            # SessionStart 钩子脚本：每次开 Codex 会话建一个日志文件
│   └── hooks.json             # Codex 钩子注册文件（SessionStart -> work-log.sh）
├── autostart/                 # 开机自启的 .desktop 项
│   ├── Clash Verge.desktop
│   └── set-proxy.desktop      # 登录时弹窗设置代理
├── clash-verge-config/        # Clash Verge Rev 的完整配置目录（含订阅与节点）
├── skills/                    # Codex skill 原样打包，装到 ~/.codex/skills/
│   └── reuse-first/           # 动手前先搜 GitHub 有没有现成方案
└── 输入法/                    # 搜狗输入法 deb 包
```

## 配什么

| 组件 | 目的 | 关键素材 |
|---|---|---|
| zsh | 把 shell 从 bash 换成 zsh，带 Oh My Zsh、自动补全、语法高亮、fzf | `脚本/install_zsh_ubuntu*.sh` + `配置/zshrc` |
| 搜狗输入法 | 中文输入（fcitx 4 框架） | `输入法/sogoupinyin_*.deb` + `脚本/install_sogou_ubuntu*.sh` |
| 护眼模式 | redshift 蓝光过滤，色温 4500K，开机自启 | `脚本/install_redshift_eyecare.sh` |
| 开机代理 | Clash Verge Rev，并在开终端时自动注入代理变量 | `clash-verge-config/` + `配置/clash-proxy.sh` + `autostart/` |
| Codex CLI（可选） | 装 Codex CLI 并接入 DeepSeek | `脚本/install_codex_ubuntu*.sh` + `codex安装.md` |
| Codex 工作日志（可选） | 每次开 Codex 会话，自动在桌面生成当日工作日志文件 | `脚本/install_worklog_hook.sh` + `配置/work-log.sh` + `配置/hooks.json` |
| reuse-first skill（可选） | 动手写脚本/工具前先搜 GitHub 有没有现成方案，避免重复造轮子 | `脚本/install_reuse_skill.sh` + `skills/reuse-first/` |

## 怎么用

### 推荐：让新电脑上的 Codex 照着提示词做

1. 把整个 `newpc-setup/` 拷到新电脑的桌面。
2. 在新电脑上打开 Codex，把 `提示词.md` 整段贴进去，或者直接说：

   > 按桌面上 `newpc-setup/提示词.md` 帮我配置。

`提示词.md` 里按顺序写清了每一步跑什么、怎么验证、失败时怎么停，建议直接照它执行。

### 手动：按需执行

先看系统版本，决定用 20.04 还是 22.04 的脚本：

```sh
. /etc/os-release && echo "Ubuntu $VERSION_ID"
```

**脚本内部自己会调 `sudo`，不要用 `sudo bash xxx.sh` 运行**，否则会把配置写进 root 的家目录。下面的命令以 22.04 为例：

```sh
# 1. zsh
bash ~/Desktop/newpc-setup/脚本/install_zsh_ubuntu2204.sh
sed "s|__HOME__|$HOME|g" ~/Desktop/newpc-setup/配置/zshrc > ~/.zshrc

# 2. 搜狗输入法：先让脚本和 deb 包在同一目录
cp ~/Desktop/newpc-setup/输入法/sogoupinyin_*.deb ~/Desktop/newpc-setup/脚本/
bash ~/Desktop/newpc-setup/脚本/install_sogou_ubuntu2204.sh

# 3. 护眼模式
bash ~/Desktop/newpc-setup/脚本/install_redshift_eyecare.sh

# 4. 开机代理（Clash Verge 本体需另行下载安装，见 提示词.md 第 4.1 节）
CV="$HOME/.local/share/io.github.clash-verge-rev.clash-verge-rev"
mkdir -p "$CV" ~/.codex ~/.config/autostart
cp -r ~/Desktop/newpc-setup/clash-verge-config/. "$CV/"
cp ~/Desktop/newpc-setup/配置/clash-proxy.sh ~/.codex/
cp ~/Desktop/newpc-setup/配置/set_proxy_gui.sh ~/ && chmod +x ~/set_proxy_gui.sh
sed "s|__HOME__|$HOME|g" ~/Desktop/newpc-setup/autostart/set-proxy.desktop \
    > ~/.config/autostart/set-proxy.desktop
cp ~/Desktop/newpc-setup/autostart/"Clash Verge.desktop" ~/.config/autostart/

# 5. 可选：Codex CLI
bash ~/Desktop/newpc-setup/脚本/install_codex_ubuntu2204.sh

# 6. 可选：Codex 会话工作日志钩子（不要加 sudo）
bash ~/Desktop/newpc-setup/脚本/install_worklog_hook.sh

# 7. 可选：reuse-first skill（不要加 sudo）
bash ~/Desktop/newpc-setup/脚本/install_reuse_skill.sh
```

`配置/zshrc` 是从旧电脑带过来的，里面有些路径只在本机存在（opencode、anaconda3、ROS 2 Humble、turtlebot3 工作空间等）。新电脑上没有的要整行注释掉，否则每次开终端都会报错。必须保留的是 `ZSH_THEME`、`plugins=(...)`、npm global bin 那行，以及最后加载 `~/.codex/clash-proxy.sh` 的两行。逐项清单见 `提示词.md` 第 1 节。

## 必读注意事项

- **搜狗要补一个系统库**：`install_sogou_ubuntu*.sh` 里除了 fcitx，还会装 `libgsettings-qt1`。
  搜狗 deb 的 `postinst` 会把自己带的旧 Qt5 目录 `/opt/sogoupinyin/files/lib/qt5` 改名成 `qt5.bak`
  （改用系统库），而它需要的 `libgsettings-qt.so.1` 只在 `libgsettings-qt1` 里，deb 的 `Depends` 没声明。
  漏装的话 `sogoupinyin-service` 起不来、fcitx 退成僵尸进程，症状是「装完搜狗还是打不了中文」。
  手动补：`sudo apt install -y libgsettings-qt1`。
- **代理的 no_proxy 必须写具体 IP**：`set_proxy_gui.sh` 写的 `/etc/profile.d/proxy.sh` 是登录级代理，
  bash 和 GUI 程序都靠它。里面 `no_proxy` 固定包含 `192.168.123.1,192.168.123.18`（机器狗）。
  Python 的 `urllib` 和 Ubuntu 20.04 的 curl 7.68 **不解析 CIDR**，只写 `192.168.0.0/16` 挡不住，
  机器狗的 ROS 流量会被丢给 Clash 而连不上。
- **Wayland 会踩坑**：搜狗输入法只在 Xorg 会话下稳定；redshift 的 `adjustment-method=randr` 在 Wayland 下失效。装完注销，在登录界面点右下角齿轮选 **Ubuntu on Xorg** 再登录。
- **隐私**：`clash-verge-config/` 里有机场订阅和节点信息，`codex安装.md` 里有代理凭据，别把这个文件夹往外传。
- **Codex 钩子要授权**：装完工作日志钩子后，第一次开新会话 Codex 会问是否信任该钩子，选信任/允许，之后才会自动建日志文件。
- **日志目录名可各机不同**：改 `~/.codex/work-log.sh` 里的 `note_name` 就能换日志根目录（默认 `cyf_note`）；重跑 `install_worklog_hook.sh` 会保留本机已改过的名字，不会被仓库默认值冲掉。
- **联网**：素材绝大多数是离线的，只有 zsh 那步（Oh My Zsh、两个插件）和 Clash Verge 本体需要联网。GitHub 拉不动时先配好代理再跑。
- **幂等**：各脚本都有「已存在就跳过」的判断，在配好的机器上重复跑一般安全；`install_redshift_eyecare.sh` 覆盖前会先备份 `~/.config/redshift.conf`。
- **跑完可删**：全部配好后 `newpc-setup/` 就可以删掉；删之前先确认不再需要里面的订阅信息。
