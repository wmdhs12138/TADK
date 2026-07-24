#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

mock_env_create() {
    local fixture_root="$1"

    MOCK_TEST_ROOT="$(mktemp -d)"
    MOCK_BIN="$MOCK_TEST_ROOT/bin"
    MOCK_PROJECT="$MOCK_TEST_ROOT/project"
    MOCK_LOG="$MOCK_TEST_ROOT/calls.log"
    MOCK_ADB_STATE_FILE="$MOCK_TEST_ROOT/adb-state"
    MOCK_INSTALLED_PACKAGES_FILE="$MOCK_TEST_ROOT/installed-packages"
    MOCK_RUNNING_PACKAGES_FILE="$MOCK_TEST_ROOT/running-packages"

    mkdir -p "$MOCK_BIN"

    cp -R "$fixture_root" "$MOCK_PROJECT"

    : > "$MOCK_LOG"
    : > "$MOCK_INSTALLED_PACKAGES_FILE"
    : > "$MOCK_RUNNING_PACKAGES_FILE"

    printf 'device\n' > "$MOCK_ADB_STATE_FILE"

    export MOCK_TEST_ROOT
    export MOCK_BIN
    export MOCK_PROJECT
    export MOCK_LOG
    export MOCK_ADB_STATE_FILE
    export MOCK_INSTALLED_PACKAGES_FILE
    export MOCK_RUNNING_PACKAGES_FILE

    export PATH="$MOCK_BIN:$PATH"

    mock_env_create_adb
    mock_env_create_gradlew
}

mock_env_destroy() {
    if [[ -n "${MOCK_TEST_ROOT:-}" ]]; then
        rm -rf "$MOCK_TEST_ROOT"
    fi
}

mock_env_create_apk() {
    local build_type="${1:-debug}"
    local apk_name="${2:-app-$build_type.apk}"
    local output_dir=""

    output_dir="$MOCK_PROJECT/app/build/outputs/apk/$build_type"

    mkdir -p "$output_dir"

    printf 'mock apk: %s\n' "$build_type" \
        > "$output_dir/$apk_name"

    printf '%s\n' "$output_dir/$apk_name"
}

mock_env_set_adb_state() {
    printf '%s\n' "$1" > "$MOCK_ADB_STATE_FILE"
}

mock_env_install_package() {
    local package_name="$1"

    grep -Fxq "$package_name" \
        "$MOCK_INSTALLED_PACKAGES_FILE" 2>/dev/null ||
        printf '%s\n' "$package_name" \
            >> "$MOCK_INSTALLED_PACKAGES_FILE"
}

mock_env_start_package() {
    local package_name="$1"

    mock_env_install_package "$package_name"

    grep -Fxq "$package_name" \
        "$MOCK_RUNNING_PACKAGES_FILE" 2>/dev/null ||
        printf '%s\n' "$package_name" \
            >> "$MOCK_RUNNING_PACKAGES_FILE"
}

mock_env_create_adb() {
    cat > "$MOCK_BIN/adb" <<'MOCK_ADB'
#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

printf 'adb' >> "$MOCK_LOG"

for argument in "$@"; do
    printf ' %q' "$argument" >> "$MOCK_LOG"
done

printf '\n' >> "$MOCK_LOG"

command_name="${1:-}"
shift || true

case "$command_name" in
    get-state)
        cat "$MOCK_ADB_STATE_FILE"
        ;;

    install)
        apk_path="${!#}"

        [[ -f "$apk_path" ]] || {
            printf 'adb: APK does not exist: %s\n' \
                "$apk_path" >&2
            exit 1
        }

        printf 'Performing Streamed Install\n'
        printf 'Success\n'
        ;;

    shell)
        shell_command="${1:-}"
        shift || true

        case "$shell_command" in
            pm)
                subcommand="${1:-}"
                shift || true

                if [[ "$subcommand" == "list" &&
                      "${1:-}" == "packages" ]]; then
                    package_name="${2:-}"

                    if grep -Fxq "$package_name" \
                        "$MOCK_INSTALLED_PACKAGES_FILE"; then
                        printf 'package:%s\n' "$package_name"
                    fi
                fi
                ;;

            pidof)
                package_name="${1:-}"

                if grep -Fxq "$package_name" \
                    "$MOCK_RUNNING_PACKAGES_FILE"; then
                    printf '12345\n'
                else
                    exit 1
                fi
                ;;

            monkey)
                package_name=""

                while [[ $# -gt 0 ]]; do
                    case "$1" in
                        -p)
                            shift
                            package_name="${1:-}"
                            ;;
                    esac

                    shift || true
                done

                if ! grep -Fxq "$package_name" \
                    "$MOCK_INSTALLED_PACKAGES_FILE"; then
                    printf 'Package not installed: %s\n' \
                        "$package_name" >&2
                    exit 1
                fi

                grep -Fxq "$package_name" \
                    "$MOCK_RUNNING_PACKAGES_FILE" ||
                    printf '%s\n' "$package_name" \
                        >> "$MOCK_RUNNING_PACKAGES_FILE"

                printf 'Events injected: 1\n'
                ;;

            am)
                if [[ "${1:-}" == "force-stop" ]]; then
                    package_name="${2:-}"
                    temporary_file="$MOCK_RUNNING_PACKAGES_FILE.tmp"

                    grep -Fxv "$package_name" \
                        "$MOCK_RUNNING_PACKAGES_FILE" \
                        > "$temporary_file" || true

                    mv \
                      "$temporary_file" \
                      "$MOCK_RUNNING_PACKAGES_FILE"
                fi
                ;;

            *)
                printf 'Unsupported adb shell command: %s\n' \
                    "$shell_command" >&2
                exit 1
                ;;
        esac
        ;;

    logcat)
        if [[ "${1:-}" == "-c" ]]; then
            exit 0
        fi

        printf '07-24 10:00:00.000 12345 12345 I MockApp: mock log\n'
        ;;

    *)
        printf 'Unsupported adb command: %s\n' \
            "$command_name" >&2
        exit 1
        ;;
esac
MOCK_ADB

    chmod +x "$MOCK_BIN/adb"
}

mock_env_create_gradlew() {
    cat > "$MOCK_PROJECT/gradlew" <<'MOCK_GRADLEW'
#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

printf './gradlew' >> "$MOCK_LOG"

for argument in "$@"; do
    printf ' %q' "$argument" >> "$MOCK_LOG"
done

printf '\n' >> "$MOCK_LOG"

for argument in "$@"; do
    case "$argument" in
        *assembleDebug)
            output_dir="$PWD/app/build/outputs/apk/debug"
            mkdir -p "$output_dir"
            printf 'mock debug apk\n' \
                > "$output_dir/app-debug.apk"
            ;;

        *assembleRelease)
            output_dir="$PWD/app/build/outputs/apk/release"
            mkdir -p "$output_dir"
            printf 'mock release apk\n' \
                > "$output_dir/app-release.apk"
            ;;
    esac
done

printf 'BUILD SUCCESSFUL in 1s\n'
MOCK_GRADLEW

    chmod +x "$MOCK_PROJECT/gradlew"
}
