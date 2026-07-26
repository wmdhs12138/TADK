#!/usr/bin/env bash

# Simplified Chinese messages for shell completion.

tadk_register_message 'command.completion.description' '生成 Shell 命令补全脚本'
tadk_register_message 'completion.unsupported_shell' '不支持的补全 Shell：%s'
tadk_register_message 'help.completion' "$(cat <<'HELP'
用法：
  tadk completion zsh

说明：
  将 Shell 命令补全脚本输出到标准输出。

  可以把输出重定向到 Zsh 的 site-functions 目录完成安装。生成的补全会读取
  当前 TADK 命令，并支持顶层命令、Release 和 config 操作、常用选项、文件、
  APK、更新归档、keystore、Logcat 格式及已授权 ADB 设备序列号。

在 Termux Zsh 中安装：
  mkdir -p "$PREFIX/share/zsh/site-functions"
  tadk completion zsh > "$PREFIX/share/zsh/site-functions/_tadk"
  rm -f ~/.zcompdump*
  exec zsh

选项：
  -h, --help          显示帮助
HELP
)"
