#!/usr/bin/env bash

# English messages for shell completion.

tadk_register_message 'command.completion.description' 'Generate and install shell completion'
tadk_register_message 'completion.unsupported_shell' 'Unsupported completion shell: %s'
tadk_register_message 'completion.install_failed' 'Unable to install Zsh completion: %s'
tadk_register_message 'completion.zshrc_invalid' 'Incomplete or duplicate TADK completion block detected: %s'
tadk_register_message 'completion.script_installed' 'Installed Zsh completion script: %s'
tadk_register_message 'completion.config_updated' 'Updated Zsh configuration: %s'
tadk_register_message 'completion.config_unchanged' 'Zsh configuration is already current: %s'
tadk_register_message 'completion.config_backup' 'Original configuration backup: %s'
tadk_register_message 'completion.reload_shell' 'Run the following command to load completion:'
tadk_register_message 'help.completion' "$(cat <<'HELP'
Usage:
  tadk completion zsh
  tadk completion install zsh

Description:
  tadk completion zsh
      Write the Zsh completion script to standard output for inspection or
      manual installation.

  tadk completion install zsh
      Install the completion script and configure ~/.zshrc using an idempotent,
      managed block. An existing .zshrc is backed up with a timestamp.
      Repeated runs do not duplicate configuration, and the earlier manual
      TADK completion snippet is migrated automatically.

After installation:
  exec zsh

Options:
  -h, --help          Show help
HELP
)"
