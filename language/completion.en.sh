#!/usr/bin/env bash

# English messages for shell completion.

tadk_register_message 'command.completion.description' 'Generate shell completion scripts'
tadk_register_message 'completion.unsupported_shell' 'Unsupported completion shell: %s'
tadk_register_message 'help.completion' "$(cat <<'HELP'
Usage:
  tadk completion zsh

Description:
  Generate a shell completion script on standard output.

  Redirect the output into Zsh's site-functions directory to install it.
  The generated completion reads the current TADK command surface and supports
  top-level commands, Release and config actions, common options, files, APKs,
  archives, keystores, Logcat formats and authorized ADB device serials.

Install for Termux Zsh:
  mkdir -p "$PREFIX/share/zsh/site-functions"
  tadk completion zsh > "$PREFIX/share/zsh/site-functions/_tadk"
  rm -f ~/.zcompdump*
  exec zsh

Options:
  -h, --help          Show help
HELP
)"
