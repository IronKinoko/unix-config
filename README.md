# macOS 工作环境迁移

本文档记录当前机器的开发环境恢复方式。应用清单以仓库根目录的
`Brewfile` 为准，当前快照验证于 2026-09-18，平台为 Apple Silicon
macOS，Homebrew 前缀为 `/opt/homebrew`。

## 1. 一键恢复

克隆仓库后，先检查脚本将要执行的操作：

```sh
./migrate.sh --dry-run
```

确认后执行：

```sh
./migrate.sh
```

脚本会完成以下工作：

1. 检查并安装 Xcode Command Line Tools。
2. 检查 Homebrew；缺失时按当前架构安装。
3. 根据 `Brewfile` 安装 formula 和 cask。
4. 备份已有 Shell 配置，并链接仓库中的 `.zshrc`、`.zprofile` 和
   `starship.toml`。
5. 校验 zsh 和 Starship 配置。

已有配置会被移动到
`~/.unix-config-backup-YYYYMMDD-HHMMSS`，不会直接覆盖。仅恢复仓库
配置、不处理 Homebrew 时可执行：

```sh
./migrate.sh --skip-brew
```

脚本完成后打开新终端，或执行：

```sh
exec zsh -l
```

## 2. 手动安装基础依赖

先安装 Xcode Command Line Tools 和 Homebrew：

```sh
xcode-select --install
```

Homebrew 安装完成后，克隆本仓库：

```sh
mkdir -p "$HOME/Developer/GitHub"
git clone https://github.com/IronKinoko/unix-config.git \
  "$HOME/Developer/GitHub/unix-config"
cd "$HOME/Developer/GitHub/unix-config"
```

## 3. 手动恢复 Homebrew 应用

`Brewfile` 只记录直接安装的 formula 和 cask；Homebrew 会自动安装它们
所需的依赖。

```sh
brew bundle check --file ./Brewfile --verbose
brew bundle install --file ./Brewfile
```

当前应用分为以下几类：

| 分类 | 应用 |
| --- | --- |
| Shell、提示符、导航 | `starship`, `zoxide`, `fnm`, `fzf` |
| 编辑器与开发工具 | `neovim`, `subversion`, `gh`, `go`, `python-setuptools`, `pkgconf` |
| 命令行工具 | `bat`, `eza`, `fastfetch`, `fd`, `ripgrep`, `shellcheck`, `unar` |
| 图像与 SVG 依赖 | `jpeg`, `librsvg` |
| GUI 与平台工具 | `ghostty`, `orbstack`, `android-platform-tools` |

当前没有 Homebrew tap，也没有需要由 `brew services` 常驻启动的服务。

## 4. 手动恢复 Shell 配置

建议用符号链接让仓库成为配置的唯一来源：

```sh
mkdir -p "$HOME/.config"
ln -sfn "$PWD/.zshrc" "$HOME/.zshrc"
ln -sfn "$PWD/.zprofile" "$HOME/.zprofile"
ln -sfn "$PWD/starship.toml" "$HOME/.config/starship.toml"
```

重新启动 Shell：

```sh
exec zsh
```

首次启动时，`.zshrc` 会自动下载 Zinit，并安装以下插件：

- `zsh-users/zsh-completions`
- `Aloxaf/fzf-tab`
- `zsh-users/zsh-autosuggestions`
- `zdharma-continuum/fast-syntax-highlighting`
- Oh My Zsh 的 `git.zsh`、`history.zsh` 和 `git` 插件

## 5. 仓库外配置

以下内容不在当前仓库中，迁移时需要单独处理：

| 路径或应用 | 用途 | 恢复方式 |
| --- | --- | --- |
| `~/.config/zsh/plugins/svn.zsh` | SVN 日常命令封装 | 从旧机器复制，或后续纳入版本管理 |
| `~/.config/sh/reset-navicat.sh` | Navicat 重置脚本 | 从旧机器复制，并确保有执行权限 |
| `~/.local/bin/env` | `uv` 等用户级工具的 Shell 环境 | 安装对应工具后按官方方式生成 |
| `~/.bun` | Bun 运行时及补全 | 单独安装 Bun；当前不是 Homebrew formula/cask |
| Navicat Premium | 数据库客户端 | 单独安装 |
| Visual Studio Code | 编辑器 | 单独安装，并另行导出扩展列表 |

API key 等秘密信息不写入仓库。迁移时应从密码管理器或受保护的本地配置
恢复，不要提交到 Git。

## 6. 验证恢复结果

```sh
brew bundle check --file ./Brewfile --verbose
zsh -n .zshrc
STARSHIP_CONFIG="$PWD/starship.toml" starship print-config >/dev/null

command -v brew starship zoxide fnm fzf nvim svn gh go
```

`brew bundle check` 在应用已安装但存在可升级版本时也可能返回非零；先查看
`brew outdated --verbose`，确认具体是缺少依赖还是版本更新。

如果 `starship print-config` 没有输出错误，并且上述命令都能找到，开发环境
的基础部分即已恢复。

## 7. 更新快照

安装或卸载 Homebrew 应用后，手工更新 `Brewfile`，然后检查：

```sh
brew bundle check --file ./Brewfile --verbose
git diff -- Brewfile README.md .zshrc starship.toml
```
