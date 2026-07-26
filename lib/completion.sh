#!/usr/bin/env bash

if [[ -n "${TADK_COMPLETION_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_COMPLETION_SH_LOADED=1

_tadk_completion_zsh() {
    cat <<'ZSH'
#compdef tadk

_tadk_command_items() {
    local -a items

    items=("${(@f)$(
        TADK_LANG=en command tadk --help 2>/dev/null |
            awk '
                /^  [[:alnum:]][[:alnum:]_-]*[[:space:]]+/ {
                    name=$1
                    $1=""
                    sub(/^[[:space:]]+/, "")
                    print name ":" $0
                }
            '
    )}")

    if (( ${#items[@]} == 0 )); then
        items=(
            'doctor:Check the development environment'
            'devices:List ADB devices'
            'connect:Manage wireless debugging connections'
            'init:Initialize an Android project'
            'config:Show or update project configuration'
            'build:Build an Android APK'
            'apk:Locate generated APK files'
            'release:Manage Release builds and signing'
            'install:Install an Android APK'
            'self-update:Verify or update TADK'
            'completion:Generate shell completion'
            'launch:Launch an Android application'
            'logcat:Read Android application logs'
            'run:Build and run an application'
            'dev:Run the development workflow'
            'clean:Clean project build files'
            'info:Show Android project information'
            'help:Show help'
            'version:Show the TADK version'
        )
    fi

    _describe -t tadk-commands 'TADK command' items
}

_tadk_release_actions() {
    local -a actions=(
        'doctor:Check the Release signing environment'
        'verify:Verify an APK signature and certificate'
        'build:Build and verify a Release APK'
        'keystore:Inspect a keystore'
        'setup:Generate a signing configuration skeleton'
        'init:Create keystore.properties'
        'keygen:Create a Release keystore'
        'apply:Apply Gradle signing configuration'
        'bootstrap:Initialize the complete signing workflow'
    )

    _describe -t tadk-release-actions 'Release action' actions
}

_tadk_config_actions() {
    local -a actions=(
        'show:Show project configuration'
        'validate:Validate project configuration'
        'set:Update project configuration'
    )

    _describe -t tadk-config-actions 'Config action' actions
}


_tadk_completion_actions() {
    local -a actions=(
        'zsh:Generate Zsh completion on standard output'
        'install:Install shell completion'
    )

    _describe -t tadk-completion-actions 'Completion action' actions
}

_tadk_authorized_devices() {
    local -a devices

    devices=("${(@f)$(
        command adb devices 2>/dev/null |
            awk 'NR > 1 && $2 == "device" { print $1 }'
    )}")

    if (( ${#devices[@]} > 0 )); then
        compadd -- "${devices[@]}"
    else
        _message 'no authorized ADB devices'
    fi
}

_tadk_help_options() {
    local command_name="$1"
    local action_name="${2:-}"
    local -a help_command options

    help_command=("$command_name")
    [[ -n "$action_name" ]] && help_command+=("$action_name")

    options=("${(@f)$(
        TADK_LANG=en command tadk "${help_command[@]}" --help 2>/dev/null |
            sed -nE \
                's/^[[:space:]]+(-[[:alnum:]],?[[:space:]]+)?(--[[:alnum:]][[:alnum:]-]*).*/\2/p' |
            awk '!seen[$0]++'
    )}")

    options+=(-h --help)
    compadd -- "${options[@]}"
}

_tadk_complete_option_value() {
    local previous="${words[CURRENT-1]}"

    case "$previous" in
        --device)
            _tadk_authorized_devices
            return 0
            ;;
        --apk)
            _files -g '*.apk'
            return 0
            ;;
        --check|--apply)
            _files -g '*.zip'
            return 0
            ;;
        --backup-dir)
            _files -/
            return 0
            ;;
        --keystore)
            _files -g '*.(jks|keystore|p12)'
            return 0
            ;;
        --module)
            _files -/
            return 0
            ;;
        --format)
            _values 'Logcat format' \
                brief process tag thread raw time threadtime long
            return 0
            ;;
        --storetype)
            _values 'keystore type' PKCS12 JKS
            return 0
            ;;
        --keyalg)
            _values 'key algorithm' RSA
            return 0
            ;;
        --keysize)
            _values 'RSA key size' 2048 3072 4096
            return 0
            ;;
        --storepass-env|--keypass-env)
            _parameters
            return 0
            ;;
    esac

    return 1
}

_tadk() {
    local command_name="${words[2]:-}"
    local action_name="${words[3]:-}"

    if (( CURRENT == 2 )); then
        _tadk_command_items
        return
    fi

    if _tadk_complete_option_value; then
        return
    fi

    case "$command_name" in
        completion)
            if (( CURRENT == 3 )); then
                _tadk_completion_actions
            elif [[ "$action_name" == install && CURRENT == 4 ]]; then
                if [[ "$PREFIX" == -* ]]; then
                    compadd -- -h --help
                else
                    _values 'shell' zsh
                fi
            elif [[ "$PREFIX" == -* ]]; then
                compadd -- -h --help
            fi
            return
            ;;
        release)
            if (( CURRENT == 3 )); then
                _tadk_release_actions
                return
            fi
            ;;
        config)
            if (( CURRENT == 3 )); then
                _tadk_config_actions
                return
            fi

            if [[ "$action_name" == set ]]; then
                if (( CURRENT == 4 )); then
                    _values 'configuration key' module variant
                    return
                fi

                if [[ "${words[4]:-}" == variant && CURRENT == 5 ]]; then
                    _values 'build variant' debug release
                    return
                fi
            fi
            ;;
    esac

    if [[ "$PREFIX" == -* ]]; then
        case "$command_name" in
            release|config)
                _tadk_help_options "$command_name" "$action_name"
                ;;
            *)
                _tadk_help_options "$command_name"
                ;;
        esac
        return
    fi

    case "$command_name" in
        doctor|init)
            _files -/
            ;;
        install)
            _files -g '*.apk'
            ;;
        self-update)
            _files -g '*.zip'
            ;;
        release)
            case "$action_name" in
                verify)
                    _files -g '*.apk'
                    ;;
                keystore)
                    _files -g '*.(jks|keystore|p12)'
                    ;;
                *)
                    _files
                    ;;
            esac
            ;;
        config)
            _files -/
            ;;
        *)
            _files
            ;;
    esac
}

_tadk "$@"
ZSH
}

_tadk_completion_install_directory() {
    if [[ -n "${PREFIX:-}" ]]; then
        printf '%s\n' "$PREFIX/share/zsh/site-functions"
    else
        printf '%s\n' "$HOME/.local/share/zsh/site-functions"
    fi
}

_tadk_completion_zshrc_block() {
    cat <<'ZSHRC'
# >>> TADK Zsh completion >>>
typeset -U fpath

if [[ -n "${PREFIX:-}" ]]; then
    fpath=("$PREFIX/share/zsh/site-functions" $fpath)
else
    fpath=("$HOME/.local/share/zsh/site-functions" $fpath)
fi

autoload -Uz compinit
(( $+functions[compdef] )) || compinit -i

autoload -Uz _tadk
compdef _tadk tadk
# <<< TADK Zsh completion <<<
ZSHRC
}

_tadk_completion_install_zsh() {
    local completion_dir=""
    local completion_file=""
    local config_root=""
    local zshrc=""
    local cache_dir=""
    local temp_dir=""
    local temp_completion=""
    local temp_zshrc=""
    local backup_path=""
    local marker_start='# >>> TADK Zsh completion >>>'
    local marker_end='# <<< TADK Zsh completion <<<'
    local start_count=0
    local end_count=0
    local config_changed=false

    completion_dir="$(_tadk_completion_install_directory)"
    completion_file="$completion_dir/_tadk"
    config_root="${ZDOTDIR:-$HOME}"
    zshrc="$config_root/.zshrc"
    cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/tadk/completion"

    mkdir -p "$completion_dir" "$config_root" "$cache_dir" || {
        tadk_die "$(tadk_text 'completion.install_failed' 'cannot create installation directories')"
    }

    if [[ -e "$zshrc" && ! -f "$zshrc" ]]; then
        tadk_die "$(tadk_text 'completion.install_failed' "$zshrc is not a regular file")"
    fi

    temp_dir="$(mktemp -d "$cache_dir/install.XXXXXX")" || {
        tadk_die "$(tadk_text 'completion.install_failed' 'cannot create temporary directory')"
    }
    trap "rm -rf -- $(printf '%q' "$temp_dir")" EXIT

    temp_completion="$temp_dir/_tadk"
    temp_zshrc="$temp_dir/zshrc"

    _tadk_completion_zsh > "$temp_completion"
    chmod 0644 "$temp_completion"
    mv -f -- "$temp_completion" "$completion_file" || {
        tadk_die "$(tadk_text 'completion.install_failed' "cannot write $completion_file")"
    }

    if [[ -f "$zshrc" ]]; then
        start_count="$(grep -Fxc -- "$marker_start" "$zshrc" || true)"
        end_count="$(grep -Fxc -- "$marker_end" "$zshrc" || true)"
    fi

    if (( start_count != end_count || start_count > 1 )); then
        tadk_die "$(tadk_text 'completion.zshrc_invalid' "$zshrc")"
    fi

    if [[ -f "$zshrc" ]]; then
        awk \
            -v start="$marker_start" \
            -v end="$marker_end" \
            -v legacy_header='# TADK Zsh completion' \
            -v legacy_fpath='fpath=("$PREFIX/share/zsh/site-functions" $fpath)' \
            -v legacy_autoload='autoload -Uz compinit' \
            -v legacy_compinit='compinit -i' \
            '
            function emit(line) {
                if (line == "") {
                    pending_blank += 1
                    return
                }

                while (pending_blank > 0) {
                    print ""
                    pending_blank -= 1
                }

                print line
            }

            $0 == start {
                skipping = 1
                next
            }

            $0 == end {
                skipping = 0
                next
            }

            skipping {
                next
            }

            $0 == legacy_header {
                first = $0

                if ((getline second) <= 0) {
                    emit(first)
                    next
                }
                if ((getline third) <= 0) {
                    emit(first)
                    emit(second)
                    next
                }
                if ((getline fourth) <= 0) {
                    emit(first)
                    emit(second)
                    emit(third)
                    next
                }

                if (second == legacy_fpath && third == legacy_autoload && fourth == legacy_compinit) {
                    next
                }

                emit(first)
                emit(second)
                emit(third)
                emit(fourth)
                next
            }

            {
                emit($0)
            }
            ' "$zshrc" > "$temp_zshrc"
    else
        : > "$temp_zshrc"
    fi

    if [[ -s "$temp_zshrc" ]]; then
        printf '\n\n' >> "$temp_zshrc"
    fi
    _tadk_completion_zshrc_block >> "$temp_zshrc"

    if [[ -f "$zshrc" ]] &&
        [[ "$(<"$temp_zshrc")" == "$(<"$zshrc")" ]]
    then
        config_changed=false
    else
        if [[ -f "$zshrc" ]]; then
            backup_path="$zshrc.tadk-backup-$(date +%Y%m%d-%H%M%S)-$$"
            cp -p -- "$zshrc" "$backup_path" || {
                tadk_die "$(tadk_text 'completion.install_failed' "cannot back up $zshrc")"
            }
        fi

        cat "$temp_zshrc" > "$zshrc" || {
            tadk_die "$(tadk_text 'completion.install_failed' "cannot update $zshrc")"
        }
        config_changed=true
    fi

    tadk_success "$(tadk_text 'completion.script_installed' "$completion_file")"

    if [[ "$config_changed" == true ]]; then
        tadk_success "$(tadk_text 'completion.config_updated' "$zshrc")"
        if [[ -n "$backup_path" ]]; then
            tadk_info "$(tadk_text 'completion.config_backup' "$backup_path")"
        fi
    else
        tadk_info "$(tadk_text 'completion.config_unchanged' "$zshrc")"
    fi

    printf '\n%s\n' "$(tadk_text 'completion.reload_shell')"
    printf '  exec zsh\n'

    rm -rf -- "$temp_dir"
    trap - EXIT
}

tadk_completion_main() {
    if (( $# == 0 )); then
        tadk_print_help 'help.completion'
        return 64
    fi

    case "$1" in
        -h|--help)
            if (( $# != 1 )); then
                tadk_die "$(tadk_text 'legacy.extra_argument' "$2")" 64
            fi
            tadk_print_help 'help.completion'
            return 0
            ;;
        zsh)
            if (( $# != 1 )); then
                tadk_die "$(tadk_text 'legacy.extra_argument' "$2")" 64
            fi
            _tadk_completion_zsh
            return 0
            ;;
        install)
            if (( $# == 1 )); then
                tadk_print_help 'help.completion'
                return 64
            fi

            if (( $# > 2 )); then
                tadk_die "$(tadk_text 'legacy.extra_argument' "$3")" 64
            fi

            case "$2" in
                -h|--help)
                    tadk_print_help 'help.completion'
                    return 0
                    ;;
                zsh)
                    _tadk_completion_install_zsh
                    return 0
                    ;;
                *)
                    tadk_die "$(tadk_text 'completion.unsupported_shell' "$2")" 64
                    ;;
            esac
            ;;
        *)
            tadk_die "$(tadk_text 'completion.unsupported_shell' "$1")" 64
            ;;
    esac
}
