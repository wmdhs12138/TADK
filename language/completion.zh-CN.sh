#!/usr/bin/env bash

# Simplified Chinese messages for shell completion.

tadk_register_message 'command.completion.description' '生成并安装 Shell 命令补全'
tadk_register_message 'completion.unsupported_shell' '不支持的补全 Shell：%s'
tadk_register_message 'completion.install_failed' '无法安装 Zsh 补全：%s'
tadk_register_message 'completion.zshrc_invalid' '检测到不完整或重复的 TADK 补全配置块：%s'
tadk_register_message 'completion.script_installed' '已安装 Zsh 补全脚本：%s'
tadk_register_message 'completion.config_updated' '已更新 Zsh 配置：%s'
tadk_register_message 'completion.config_unchanged' 'Zsh 配置已经是最新状态：%s'
tadk_register_message 'completion.config_backup' '原配置备份：%s'
tadk_register_message 'completion.reload_shell' '运行以下命令加载补全：'
tadk_register_message 'help.completion' "$(cat <<'HELP'
用法：
  tadk completion zsh
  tadk completion install zsh

说明：
  tadk completion zsh
      将 Zsh 命令补全脚本输出到标准输出，适合检查或手动安装。

  tadk completion install zsh
      自动安装补全脚本，并以受管理、可重复执行的方式配置 ~/.zshrc。
      已有 .zshrc 会先创建带时间戳的备份；重复执行不会重复添加配置。
      旧版手动添加的 TADK 补全配置会自动迁移为受管理配置块。

安装完成后执行：
  exec zsh

选项：
  -h, --help          显示帮助
HELP
)"
