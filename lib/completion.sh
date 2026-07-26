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
                _values 'shell' zsh
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
        *)
            tadk_die "$(tadk_text 'completion.unsupported_shell' "$1")" 64
            ;;
    esac
}
