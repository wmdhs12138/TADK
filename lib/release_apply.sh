#!/data/data/com.termux/files/usr/bin/bash

if [[ -n "${TADK_RELEASE_APPLY_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_RELEASE_APPLY_SH_LOADED=1

readonly TADK_RELEASE_APPLY_BEGIN="// TADK Release signing begin"
readonly TADK_RELEASE_APPLY_END="// TADK Release signing end"

tadk_release_apply_resolve_build_file() {
    if (( $# != 3 )); then
        tadk_error \
            "内部错误：Gradle 文件解析需要项目、模块和 DSL"
        return 64
    fi

    local project_root="$1"
    local module="$2"
    local dsl="$3"

    case "$dsl" in
        kotlin)
            printf '%s/%s/build.gradle.kts\n' \
                "$project_root" \
                "$module"
            ;;

        groovy)
            printf '%s/%s/build.gradle\n' \
                "$project_root" \
                "$module"
            ;;

        *)
            tadk_error \
                "内部错误：未知 Gradle DSL：$dsl"
            return 64
            ;;
    esac
}

tadk_release_apply_count_marker() {
    if (( $# != 2 )); then
        tadk_error \
            "内部错误：标记计数需要文件和标记"
        return 64
    fi

    local target_path="$1"
    local marker="$2"

    grep -Fxc -- "$marker" "$target_path" 2>/dev/null || true
}

tadk_release_apply_check_markers() {
    if (( $# != 1 )); then
        tadk_error \
            "内部错误：标记检查需要 Gradle 文件"
        return 64
    fi

    local target_path="$1"
    local begin_count=0
    local end_count=0
    local begin_line=0
    local end_line=0

    begin_count="$(
        tadk_release_apply_count_marker \
            "$target_path" \
            "$TADK_RELEASE_APPLY_BEGIN"
    )"

    end_count="$(
        tadk_release_apply_count_marker \
            "$target_path" \
            "$TADK_RELEASE_APPLY_END"
    )"

    if (( begin_count == 0 && end_count == 0 )); then
        printf '%s\n' "absent"
        return 0
    fi

    if (( begin_count == 1 && end_count == 1 )); then
        begin_line="$(
            grep -Fnx \
                "$TADK_RELEASE_APPLY_BEGIN" \
                "$target_path" |
                cut -d: -f1
        )"

        end_line="$(
            grep -Fnx \
                "$TADK_RELEASE_APPLY_END" \
                "$target_path" |
                cut -d: -f1
        )"

        if (( begin_line < end_line )); then
            printf '%s\n' "present"
            return 0
        fi
    fi

    tadk_error \
        "Gradle 文件中的 TADK 签名标记不完整、重复或顺序错误"
    tadk_error \
        "请先人工检查：$target_path"
    return 1
}

tadk_release_apply_has_existing_signing_config() {
    if (( $# != 1 )); then
        tadk_error \
            "内部错误：签名配置检查需要 Gradle 文件"
        return 64
    fi

    local target_path="$1"

    grep -Eq \
        '(^|[^A-Za-z0-9_])(signingConfigs|signingConfig)([^A-Za-z0-9_]|$)' \
        "$target_path"
}

tadk_release_apply_write_kotlin_block() {
    if (( $# != 1 )); then
        tadk_error \
            "内部错误：Kotlin 签名块写入需要目标文件"
        return 64
    fi

    local target_path="$1"

    cat >> "$target_path" <<'KOTLIN'

// TADK Release signing begin
val tadkReleaseKeystoreFile =
    rootProject.file("keystore.properties")
val tadkReleaseKeystoreProperties =
    java.util.Properties()

if (tadkReleaseKeystoreFile.isFile) {
    tadkReleaseKeystoreFile.inputStream().use {
        tadkReleaseKeystoreProperties.load(it)
    }
}

android {
    signingConfigs {
        maybeCreate("release").apply {
            check(tadkReleaseKeystoreFile.isFile) {
                "Missing keystore.properties"
            }

            storeFile = rootProject.file(
                tadkReleaseKeystoreProperties.getProperty(
                    "storeFile"
                )
            )
            storePassword =
                tadkReleaseKeystoreProperties.getProperty(
                    "storePassword"
                )
            keyAlias =
                tadkReleaseKeystoreProperties.getProperty(
                    "keyAlias"
                )
            keyPassword =
                tadkReleaseKeystoreProperties.getProperty(
                    "keyPassword"
                )
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig =
                signingConfigs.getByName("release")
        }
    }
}
// TADK Release signing end
KOTLIN
}

tadk_release_apply_write_groovy_block() {
    if (( $# != 1 )); then
        tadk_error \
            "内部错误：Groovy 签名块写入需要目标文件"
        return 64
    fi

    local target_path="$1"

    cat >> "$target_path" <<'GROOVY'

// TADK Release signing begin
def tadkReleaseKeystoreFile =
    rootProject.file("keystore.properties")
def tadkReleaseKeystoreProperties =
    new Properties()

if (tadkReleaseKeystoreFile.isFile()) {
    tadkReleaseKeystoreFile.withInputStream {
        tadkReleaseKeystoreProperties.load(it)
    }
}

android {
    signingConfigs {
        maybeCreate("release").with {
            if (!tadkReleaseKeystoreFile.isFile()) {
                throw new GradleException(
                    "Missing keystore.properties"
                )
            }

            storeFile rootProject.file(
                tadkReleaseKeystoreProperties["storeFile"]
            )
            storePassword(
                tadkReleaseKeystoreProperties[
                    "storePassword"
                ]
            )
            keyAlias(
                tadkReleaseKeystoreProperties["keyAlias"]
            )
            keyPassword(
                tadkReleaseKeystoreProperties["keyPassword"]
            )
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
// TADK Release signing end
GROOVY
}

tadk_release_apply_replace_existing_block() {
    if (( $# != 2 )); then
        tadk_error \
            "内部错误：签名块移除需要源文件和目标文件"
        return 64
    fi

    local source_path="$1"
    local target_path="$2"

    awk \
        -v begin="$TADK_RELEASE_APPLY_BEGIN" \
        -v end="$TADK_RELEASE_APPLY_END" \
        '
        $0 == begin {
            inside = 1
            next
        }

        $0 == end {
            inside = 0
            next
        }

        !inside {
            print
        }
        ' \
        "$source_path" \
        > "$target_path"
}

tadk_release_apply_execute() {
    if (( $# != 4 )); then
        tadk_error \
            "内部错误：release apply 需要模块、force、check 和项目路径"
        return 64
    fi

    local requested_module="$1"
    local force="$2"
    local check_only="$3"
    local project_root="$4"

    local module=""
    local dsl=""
    local build_file=""
    local marker_state=""
    local temporary_path=""
    local original_mode=""

    case "$force" in
        true|false)
            ;;
        *)
            tadk_error \
                "内部错误：无效的覆盖选项：$force"
            return 64
            ;;
    esac

    case "$check_only" in
        true|false)
            ;;
        *)
            tadk_error \
                "内部错误：无效的检查选项：$check_only"
            return 64
            ;;
    esac

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

    build_file="$(
        tadk_release_apply_resolve_build_file \
            "$project_root" \
            "$module" \
            "$dsl"
    )" || return $?

    [[ -f "$build_file" && ! -L "$build_file" ]] || {
        tadk_error \
            "Gradle 构建文件不是普通文件：$build_file"
        return 1
    }

    marker_state="$(
        tadk_release_apply_check_markers \
            "$build_file"
    )" || return $?

    if [[ "$marker_state" == absent ]] &&
       tadk_release_apply_has_existing_signing_config \
           "$build_file"; then
        tadk_error \
            "检测到已有 signingConfig，拒绝自动修改"
        tadk_error \
            "请先人工确认现有签名配置：$build_file"
        return 1
    fi

    tadk_heading "TADK Release Apply"
    tadk_separator
    printf '项目：%s\n' "$project_root"
    printf '模块：%s\n' "$module"
    printf 'Gradle DSL：%s\n' "$dsl"
    printf '构建文件：%s\n' "$build_file"
    printf '当前状态：%s\n' "$marker_state"
    printf '检查模式：%s\n' "$check_only"
    printf '覆盖 TADK 配置：%s\n' "$force"
    tadk_separator

    if [[ "$check_only" == true ]]; then
        if [[ "$marker_state" == present ]]; then
            tadk_success "TADK Release 签名配置已应用"
            return 0
        fi

        tadk_error "TADK Release 签名配置尚未应用"
        return 1
    fi

    if [[ "$marker_state" == present &&
          "$force" != true ]]; then
        tadk_success "TADK Release 签名配置已存在，无需修改"
        return 0
    fi

    temporary_path="$build_file.tadk.$$"

    [[ ! -e "$temporary_path" ]] || {
        tadk_error \
            "临时文件已存在：$temporary_path"
        return 1
    }

    original_mode="$(stat -c '%a' "$build_file")"

    if [[ "$marker_state" == present ]]; then
        if ! tadk_release_apply_replace_existing_block \
            "$build_file" \
            "$temporary_path"; then
            rm -f -- "$temporary_path"
            tadk_error "无法移除已有 TADK 签名配置"
            return 1
        fi
    else
        if ! cp -- "$build_file" "$temporary_path"; then
            rm -f -- "$temporary_path"
            tadk_error "无法创建 Gradle 临时副本"
            return 1
        fi
    fi

    case "$dsl" in
        kotlin)
            if ! tadk_release_apply_write_kotlin_block \
                "$temporary_path"; then
                rm -f -- "$temporary_path"
                tadk_error "无法写入 Kotlin DSL 签名配置"
                return 1
            fi
            ;;

        groovy)
            if ! tadk_release_apply_write_groovy_block \
                "$temporary_path"; then
                rm -f -- "$temporary_path"
                tadk_error "无法写入 Groovy DSL 签名配置"
                return 1
            fi
            ;;
    esac

    chmod "$original_mode" "$temporary_path"

    if ! mv -f -- "$temporary_path" "$build_file"; then
        rm -f -- "$temporary_path"
        tadk_error "无法替换 Gradle 构建文件"
        return 1
    fi

    tadk_success "已应用 Release 签名配置：$build_file"
    tadk_info "下一步：tadk release build"
}
