#!/usr/bin/env bash

# TADK language loading and message lookup.
#
# Language resources are intentionally kept outside command implementations so
# the command layer only deals with message identifiers and values.

if [[ -n "${TADK_LANGUAGE_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_LANGUAGE_SH_LOADED=1

declare -gA TADK_MESSAGES=()

tadk_register_message() {
    local key="$1"
    local value="$2"

    TADK_MESSAGES["$key"]="$value"
}

tadk_language_normalize() {
    local requested="${1:-}"

    requested="${requested,,}"

    case "$requested" in
        zh|zh-cn|zh_cn|zh-hans|zh-hans-cn|zh_cn.*|zh-cn.*)
            printf '%s\n' 'zh-CN'
            ;;
        en|en-us|en_us|en-gb|en_gb|c|posix|en_*)
            printf '%s\n' 'en'
            ;;
        *)
            return 1
            ;;
    esac
}

tadk_language_load() {
    local language_dir="${TADK_ROOT:-$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/language"
    local requested="${TADK_LANG:-${TADK_LANGUAGE:-}}"
    local detected="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
    local selected=""

    if [[ -n "$requested" ]]; then
        selected="$(tadk_language_normalize "$requested" || true)"
    else
        selected="$(tadk_language_normalize "$detected" || true)"
    fi

    # Keep the existing Chinese CLI behavior when no locale is available.
    selected="${selected:-zh-CN}"

    case "$selected" in
        en)
            source "$language_dir/en.sh"
            ;;
        zh-CN)
            source "$language_dir/zh-CN.sh"
            ;;
        *)
            selected='zh-CN'
            source "$language_dir/zh-CN.sh"
            ;;
    esac

    readonly TADK_LANGUAGE="$selected"
}

tadk_language_has_key() {
    local key="$1"

    [[ -n "${TADK_MESSAGES[$key]+present}" ]]
}

tadk_text() {
    local key="$1"
    local template=""

    if tadk_language_has_key "$key"; then
        template="${TADK_MESSAGES[$key]}"
    else
        template="$key"
    fi

    shift

    if (( $# == 0 )); then
        printf '%s' "$template"
    else
        printf -- "$template" "$@"
    fi
}

tadk_print_help() {
    tadk_text "$1"
    printf '\n'
}

tadk_label() {
    local key="$1"

    shift
    printf '%s\n' "$(tadk_text "label.$key" "$@")"
}

tadk_localize_legacy() {
    local message="$1"
    local value=""

    case "$message" in
        '未知参数：'*)
            value="${message#未知参数：}"
            tadk_text 'legacy.unknown_option' "$value"
            ;;
        '未知 config 子命令：'*)
            value="${message#未知 config 子命令：}"
            tadk_text 'legacy.unknown_subcommand' "$value"
            ;;
        '未知 release 操作：'*)
            value="${message#未知 release 操作：}"
            tadk_text 'legacy.unknown_action' "$value"
            ;;
        '内部错误：'*)
            value="${message#内部错误：}"
            tadk_text 'legacy.internal_error' "$value"
            ;;
        '项目目录不存在：'*)
            value="${message#项目目录不存在：}"
            tadk_text 'legacy.project_path_missing' "$value"
            ;;
        '拒绝删除空路径')
            tadk_text 'legacy.reject_empty_path'
            ;;
        '拒绝删除根目录')
            tadk_text 'legacy.reject_root_path'
            ;;
        '拒绝删除 HOME 目录')
            tadk_text 'legacy.reject_home_path'
            ;;
        '拒绝删除项目目录之外的路径：'*)
            tadk_text 'legacy.reject_outside_path' "${message#拒绝删除项目目录之外的路径：}"
            ;;
        '指定目录不在有效的 Gradle Android 项目中：'*)
            value="${message#指定目录不在有效的 Gradle Android 项目中：}"
            tadk_text 'legacy.project_path_invalid' "$value"
            ;;
        '当前目录不在有效的 Gradle Android 项目中')
            tadk_text 'legacy.project_current_invalid'
            ;;
        '项目配置不存在：'*)
            value="${message#项目配置不存在：}"
            tadk_text 'legacy.config_missing' "$value"
            ;;
        '无法加载项目配置，状态码：'*)
            value="${message#无法加载项目配置，状态码：}"
            tadk_text 'legacy.config_load_failed' "$value"
            ;;
        '请执行：pkg install android-tools')
            tadk_text 'adb.install_hint'
            ;;
        '无法确定模块 Gradle 构建任务')
            tadk_text 'legacy.gradle_module_task_missing'
            ;;
        '无法确定 Gradle 构建任务')
            tadk_text 'legacy.gradle_task_missing'
            ;;
        *缺少*)
            value="${message%% 缺少*}"
            tadk_text 'legacy.option_missing' "$value"
            ;;
        *不能重复指定*)
            value="${message%% 不能重复指定}"
            tadk_text 'legacy.option_duplicate' "$value"
            ;;
        *不能与*同时使用*)
            value="${message%% 不能与*}"
            local second="${message#*不能与 }"
            second="${second% 同时使用}"
            tadk_text 'legacy.option_conflict' "$value" "$second"
            ;;
        *只能指定一个*)
            tadk_text 'legacy.single_value' "$message"
            ;;
        '多余参数：'*)
            tadk_text 'legacy.extra_argument' "${message#多余参数：}"
            ;;
        *不支持参数：*)
            value="${message%% 不支持参数：*}"
            local unsupported="${message#*不支持参数：}"
            tadk_text 'legacy.unsupported_argument' "$value" "$unsupported"
            ;;
        '不支持的日志格式：'*)
            tadk_text 'legacy.unsupported_format' "${message#不支持的日志格式：}"
            ;;
        *'必须是大于 0 的整数')
            value="${message%% 必须是大于*}"
            tadk_text 'legacy.positive_integer' "$value"
            ;;
        'APK 不存在或不是有效的 APK 文件：'*)
            value="${message#APK 不存在或不是有效的 APK 文件：}"
            tadk_text 'legacy.apk_invalid' "$value"
            ;;
        'APK 不存在：'*)
            value="${message#APK 不存在：}"
            tadk_text 'legacy.apk_missing' "$value"
            ;;
        未找到*APK，请先执行：*)
            tadk_text 'legacy.apk_not_found_build' "${message#未找到 }"
            ;;
        '应用启动失败：'*)
            value="${message#应用启动失败：}"
            tadk_text 'legacy.app_start_failed' "$value"
            ;;
        '应用已启动')
            tadk_text 'legacy.app_started'
            ;;
        '无法识别 applicationId，已跳过启动')
            tadk_text 'legacy.app_id_missing_skip'
            ;;
        '无法识别应用包名，不能进入日志')
            tadk_text 'legacy.package_missing_logcat'
            ;;
        无法识别应用包名，请使用：*)
            tadk_text 'legacy.package_missing' "${message#无法识别应用包名，请使用：}"
            ;;
        '无法识别应用包名，不能进入日志')
            tadk_text 'legacy.package_missing_logcat'
            ;;
        '等待应用进程超时：'*)
            value="${message#等待应用进程超时：}"
            tadk_text 'legacy.app_wait_timeout' "$value"
            ;;
        '等待应用启动：'*)
            value="${message#等待应用启动：}"
            tadk_text 'legacy.app_waiting' "$value"
            ;;
        '应用未运行，正在启动：'*)
            value="${message#应用未运行，正在启动：}"
            tadk_text 'legacy.app_launching' "$value"
            ;;
        '停止应用：'*)
            value="${message#停止应用：}"
            tadk_text 'legacy.app_stopping' "$value"
            ;;
        '无法停止应用：'*)
            value="${message#无法停止应用：}"
            tadk_text 'legacy.app_stop_failed' "$value"
            ;;
        构建成功，用时*)
            value="${message#构建成功，用时 }"
            tadk_text 'legacy.build_succeeded' "$value"
            ;;
        'APK：'*)
            value="${message#APK：}"
            tadk_text 'legacy.apk_label' "$value"
            ;;
        '大小：'*)
            value="${message#大小：}"
            tadk_text 'legacy.size_label' "$value"
            ;;
        构建完成，但未找到*)
            value="${message#构建完成，但未找到 }"
            tadk_text 'legacy.build_apk_missing' "$value"
            ;;
        '清理完成')
            tadk_text 'legacy.clean_succeeded'
            ;;
        '没有发现需要清理的项目缓存')
            tadk_text 'legacy.clean_nothing'
            ;;
        '项目配置有效：'*)
            value="${message#项目配置有效：}"
            tadk_text 'legacy.config_valid' "$value"
            ;;
        '项目配置已更新：'*)
            value="${message#项目配置已更新：}"
            tadk_text 'legacy.config_updated' "$value"
            ;;
        'ADB 连接失败')
            tadk_text 'legacy.adb_connect_failed'
            ;;
        'ADB 连接成功')
            tadk_text 'legacy.adb_connect_succeeded'
            ;;
        'ADB 配对失败')
            tadk_text 'legacy.adb_pair_failed'
            ;;
        'ADB 配对完成')
            tadk_text 'legacy.adb_pair_succeeded'
            ;;
        'ADB 断开失败')
            tadk_text 'legacy.adb_disconnect_failed'
            ;;
        'ADB 设备已断开')
            tadk_text 'legacy.adb_disconnected'
            ;;
        '应用启动失败：'*)
            value="${message#应用启动失败：}"
            tadk_text 'legacy.app_start_failed' "$value"
            ;;
        构建成功，用时*)
            value="${message#构建成功，用时 }"
            tadk_text 'legacy.build_succeeded' "$value"
            ;;
        步骤*)
            value="${message#步骤 }"
            tadk_text 'legacy.step' "$value"
            ;;
        'Termux environment: '*)
            tadk_text 'doctor.termux_found' "${message#Termux environment: }"
            ;;
        'Termux environment was not detected')
            tadk_text 'doctor.termux_missing'
            ;;
        'Bash found: '*)
            tadk_text 'doctor.bash_found' "${message#Bash found: }"
            ;;
        'Bash was not found in PATH')
            tadk_text 'doctor.bash_missing'
            ;;
        'Java found: '*)
            tadk_text 'doctor.java_found' "${message#Java found: }"
            ;;
        'Java was not found in PATH')
            tadk_text 'doctor.java_missing'
            ;;
        'Gradle Wrapper does not exist: '*)
            tadk_text 'doctor.wrapper_missing' "${message#Gradle Wrapper does not exist: }"
            ;;
        'Gradle Wrapper is not readable: '*)
            tadk_text 'doctor.wrapper_unreadable' "${message#Gradle Wrapper is not readable: }"
            ;;
        'Gradle Wrapper is not executable: '*)
            tadk_text 'doctor.wrapper_unexecutable' "${message#Gradle Wrapper is not executable: }"
            ;;
        'Gradle Wrapper found: '*)
            tadk_text 'doctor.wrapper_found' "${message#Gradle Wrapper found: }"
            ;;
        'Neither ANDROID_HOME nor ANDROID_SDK_ROOT is set')
            tadk_text 'doctor.sdk_vars_missing'
            ;;
        'Android SDK directory does not exist: '*)
            tadk_text 'doctor.sdk_missing' "${message#Android SDK directory does not exist: }"
            ;;
        'Android SDK found: '*)
            tadk_text 'doctor.sdk_found' "${message#Android SDK found: }"
            ;;
        'ADB was not found in PATH')
            tadk_text 'doctor.adb_missing'
            ;;
        'ADB found: '*)
            tadk_text 'doctor.adb_found' "${message#ADB found: }"
            ;;
        'At least one authorized ADB device is connected')
            tadk_text 'doctor.adb_ready'
            ;;
        'No authorized ADB device is connected')
            tadk_text 'doctor.adb_not_ready'
            ;;
        'Android manifest found: '*)
            tadk_text 'doctor.manifest_found' "${message#Android manifest found: }"
            ;;
        'No AndroidManifest.xml was found')
            tadk_text 'doctor.manifest_missing'
            ;;
        'APK output directory found: '*)
            tadk_text 'doctor.apk_output_found' "${message#APK output directory found: }"
            ;;
        'No APK output directory exists yet')
            tadk_text 'doctor.apk_output_missing'
            ;;
        TADK*)
            printf '%s' "$message"
            ;;
        *)
            printf '%s' "$message"
            ;;
    esac
}

tadk_language_load
