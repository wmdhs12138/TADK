#!/usr/bin/env bash

if [[ -n "${TADK_RELEASE_SETUP_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_RELEASE_SETUP_SH_LOADED=1

readonly TADK_RELEASE_SETUP_IGNORE_BEGIN="# TADK Release signing"
readonly TADK_RELEASE_SETUP_IGNORE_END="# End TADK Release signing"

_TADK_RELEASE_SETUP_MODULE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$_TADK_RELEASE_SETUP_MODULE_DIR/module.sh"
unset _TADK_RELEASE_SETUP_MODULE_DIR

tadk_release_setup_validate_module() {
    if (( $# != 1 )); then
        return 64
    fi

    local module="$1"

    tadk_module_validate "$module"
}

tadk_release_setup_resolve_module() {
    if (( $# != 2 )); then
        tadk_error \
            "内部错误：setup 模块解析需要项目路径和显式模块"
        return 64
    fi

    local project_root="$1"
    local requested_module="$2"
    local config_status=0
    local module=""

    if [[ -n "$requested_module" ]]; then
        tadk_release_setup_validate_module "$requested_module" || {
            tadk_error "无效的 Android 模块名称：$requested_module"
            return 64
        }

        module="$requested_module"
    elif tadk_config_load "$project_root"; then
        module="$TADK_CONFIG_MODULE"
    else
        config_status=$?

        if (( config_status != 1 )); then
            tadk_error \
                "无法加载项目配置，状态码：$config_status"
            return "$config_status"
        fi

        if [[ -f "$project_root/app/build.gradle.kts" ||
              -f "$project_root/app/build.gradle" ]]; then
            module="app"
        else
            tadk_error \
                "无法确定 Android 模块；请使用 --module MODULE"
            return 1
        fi
    fi

    [[ -d "$project_root/$module" ]] || {
        tadk_error \
            "Android 模块目录不存在：$project_root/$module"
        return 1
    }

    printf '%s\n' "$module"
}

tadk_release_setup_detect_dsl() {
    if (( $# != 2 )); then
        tadk_error \
            "内部错误：DSL 检测需要项目路径和模块"
        return 64
    fi

    local project_root="$1"
    local module="$2"
    local kotlin_file="$project_root/$module/build.gradle.kts"
    local groovy_file="$project_root/$module/build.gradle"

    if [[ -f "$kotlin_file" && -f "$groovy_file" ]]; then
        tadk_error \
            "模块同时存在 build.gradle.kts 和 build.gradle：$module"
        return 1
    fi

    if [[ -f "$kotlin_file" ]]; then
        printf '%s\n' "kotlin"
        return 0
    fi

    if [[ -f "$groovy_file" ]]; then
        printf '%s\n' "groovy"
        return 0
    fi

    tadk_error \
        "模块中未找到 build.gradle.kts 或 build.gradle：$module"
    return 1
}

tadk_release_setup_preflight_targets() {
    if (( $# < 2 )); then
        tadk_error \
            "内部错误：setup 目标预检需要覆盖选项和目标路径"
        return 64
    fi

    local force="$1"
    shift

    local target_path=""

    case "$force" in
        true|false)
            ;;
        *)
            tadk_error "内部错误：无效的覆盖选项：$force"
            return 64
            ;;
    esac

    if [[ "$force" == true ]]; then
        return 0
    fi

    for target_path in "$@"; do
        if [[ -e "$target_path" ]]; then
            tadk_error "文件已存在，不会覆盖：$target_path"
            tadk_error \
                "确认覆盖时请使用：tadk release setup --force"
            return 1
        fi
    done
}

tadk_release_setup_write_properties_example() {
    if (( $# != 2 )); then
        tadk_error \
            "内部错误：properties 模板写入需要目标路径和覆盖选项"
        return 64
    fi

    local target_path="$1"
    local force="$2"

    if [[ -e "$target_path" && "$force" != true ]]; then
        tadk_error \
            "文件已存在，不会覆盖：$target_path"
        tadk_error \
            "确认覆盖时请使用：tadk release setup --force"
        return 1
    fi

    cat > "$target_path" <<'PROPERTIES'
# Copy this file to keystore.properties and replace the placeholders.
#
# Never commit keystore.properties or the keystore itself.

storeFile=release.jks
storePassword=CHANGE_ME
keyAlias=release
keyPassword=CHANGE_ME
PROPERTIES
}

tadk_release_setup_write_kotlin_snippet() {
    if (( $# != 2 )); then
        tadk_error \
            "内部错误：Kotlin DSL 模板写入需要目标路径和覆盖选项"
        return 64
    fi

    local target_path="$1"
    local force="$2"

    if [[ -e "$target_path" && "$force" != true ]]; then
        tadk_error \
            "文件已存在，不会覆盖：$target_path"
        tadk_error \
            "确认覆盖时请使用：tadk release setup --force"
        return 1
    fi

    cat > "$target_path" <<'KOTLIN'
/*
 * TADK Release signing snippet for build.gradle.kts
 *
 * Copy the relevant sections into the module's android configuration.
 * This file is documentation and is not applied automatically.
 */

import java.util.Properties

val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties()

if (keystorePropertiesFile.isFile) {
    keystorePropertiesFile.inputStream().use {
        keystoreProperties.load(it)
    }
}

android {
    signingConfigs {
        create("release") {
            check(keystorePropertiesFile.isFile) {
                "Missing keystore.properties"
            }

            storeFile = rootProject.file(
                keystoreProperties.getProperty("storeFile")
            )
            storePassword = keystoreProperties.getProperty(
                "storePassword"
            )
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty(
                "keyPassword"
            )
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
KOTLIN
}

tadk_release_setup_write_groovy_snippet() {
    if (( $# != 2 )); then
        tadk_error \
            "内部错误：Groovy DSL 模板写入需要目标路径和覆盖选项"
        return 64
    fi

    local target_path="$1"
    local force="$2"

    if [[ -e "$target_path" && "$force" != true ]]; then
        tadk_error \
            "文件已存在，不会覆盖：$target_path"
        tadk_error \
            "确认覆盖时请使用：tadk release setup --force"
        return 1
    fi

    cat > "$target_path" <<'GROOVY'
/*
 * TADK Release signing snippet for build.gradle
 *
 * Copy the relevant sections into the module's android configuration.
 * This file is documentation and is not applied automatically.
 */

def keystorePropertiesFile = rootProject.file("keystore.properties")
def keystoreProperties = new Properties()

if (keystorePropertiesFile.isFile()) {
    keystorePropertiesFile.withInputStream {
        keystoreProperties.load(it)
    }
}

android {
    signingConfigs {
        release {
            if (!keystorePropertiesFile.isFile()) {
                throw new GradleException(
                    "Missing keystore.properties"
                )
            }

            storeFile rootProject.file(
                keystoreProperties["storeFile"]
            )
            storePassword keystoreProperties["storePassword"]
            keyAlias keystoreProperties["keyAlias"]
            keyPassword keystoreProperties["keyPassword"]
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
GROOVY
}

tadk_release_setup_update_gitignore() {
    if (( $# != 1 )); then
        tadk_error \
            "内部错误：gitignore 更新需要项目路径"
        return 64
    fi

    local project_root="$1"
    local gitignore_path="$project_root/.gitignore"

    touch "$gitignore_path"

    if grep -Fqx \
        "$TADK_RELEASE_SETUP_IGNORE_BEGIN" \
        "$gitignore_path"; then
        return 0
    fi

    if [[ -s "$gitignore_path" ]]; then
        printf '\n' >> "$gitignore_path"
    fi

    cat >> "$gitignore_path" <<EOF_IGNORE
$TADK_RELEASE_SETUP_IGNORE_BEGIN
/keystore.properties
/release.jks
$TADK_RELEASE_SETUP_IGNORE_END
EOF_IGNORE
}

tadk_release_setup_execute() {
    if (( $# != 3 )); then
        tadk_error \
            "内部错误：setup 执行需要模块、覆盖选项和项目路径"
        return 64
    fi

    local requested_module="$1"
    local force="$2"
    local project_root="$3"

    local module=""
    local dsl=""
    local tadk_directory="$project_root/.tadk"
    local properties_path="$project_root/keystore.properties.example"
    local snippet_path=""

    module="$(
        tadk_release_setup_resolve_module \
            "$project_root" \
            "$requested_module"
    )" || return $?

    dsl="$(
        tadk_release_setup_detect_dsl \
            "$project_root" \
            "$module"
    )" || return $?

    case "$dsl" in
        kotlin)
            snippet_path="$tadk_directory/release-signing-snippet.gradle.kts"
            ;;

        groovy)
            snippet_path="$tadk_directory/release-signing-snippet.gradle"
            ;;

        *)
            tadk_error "内部错误：未知 Gradle DSL：$dsl"
            return 64
            ;;
    esac

    tadk_release_setup_preflight_targets \
        "$force" \
        "$properties_path" \
        "$snippet_path" ||
        return $?

    tadk_heading "TADK Release Setup"
    tadk_separator
    printf '项目：%s\n' "$project_root"
    printf '模块：%s\n' "$module"
    printf 'Gradle DSL：%s\n' "$dsl"
    printf '覆盖已有模板：%s\n' "$force"
    tadk_separator

    mkdir -p "$tadk_directory"

    tadk_release_setup_write_properties_example \
        "$properties_path" \
        "$force"

    case "$dsl" in
        kotlin)
            tadk_release_setup_write_kotlin_snippet \
                "$snippet_path" \
                "$force"
            ;;

        groovy)
            tadk_release_setup_write_groovy_snippet \
                "$snippet_path" \
                "$force"
            ;;
    esac

    tadk_release_setup_update_gitignore "$project_root"

    tadk_success "已生成：$properties_path"
    tadk_success "已生成：$snippet_path"
    tadk_success "已更新：$project_root/.gitignore"

    printf '\n后续步骤：\n'
    printf '  1. 复制 keystore.properties.example 为 keystore.properties\n'
    printf '  2. 填写本地 keystore 路径、alias 和密码\n'
    printf '  3. 将签名片段整合进 %s/build.gradle' "$module"

    if [[ "$dsl" == kotlin ]]; then
        printf '.kts\n'
    else
        printf '\n'
    fi

    printf '  4. 执行 tadk release build\n'
}
