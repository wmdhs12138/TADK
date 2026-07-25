#!/usr/bin/env bash

set -Eeuo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$HOME/.cache/tadk/release-command-test-$$"
MOCK_BIN="$TEST_ROOT/bin"
MOCK_PROJECT="$TEST_ROOT/project"
MOCK_LOG="$TEST_ROOT/commands.log"

cleanup() {
    rm -rf "$TEST_ROOT"
}

trap cleanup EXIT

mkdir -p \
    "$MOCK_BIN" \
    "$MOCK_PROJECT/app/build/outputs/apk/release"

: > "$MOCK_LOG"

cat > "$MOCK_PROJECT/gradlew" <<'GRADLEW'
#!/usr/bin/env bash

set -Eeuo pipefail

printf 'gradlew' >> "$MOCK_LOG"

for argument in "$@"; do
    printf ' %q' "$argument" >> "$MOCK_LOG"
done

printf '\n' >> "$MOCK_LOG"
GRADLEW

cat > "$MOCK_PROJECT/settings.gradle.kts" <<'SETTINGS'
rootProject.name = "ReleaseFixture"
include(":app")
SETTINGS

chmod +x "$MOCK_PROJECT/gradlew"

RELEASE_APK="$MOCK_PROJECT/app/build/outputs/apk/release/app-release.apk"
UNSIGNED_APK="$MOCK_PROJECT/app/build/outputs/apk/release/app-unsigned.apk"

printf 'signed apk fixture\n' > "$RELEASE_APK"
printf 'unsigned apk fixture\n' > "$UNSIGNED_APK"

cat > "$MOCK_BIN/keytool" <<'MOCK_KEYTOOL'
#!/usr/bin/env bash

set -Eeuo pipefail

if [[ "${MOCK_KEYTOOL_FAIL:-false}" == true ]]; then
    exit 23
fi

printf 'keytool' >> "$MOCK_LOG"

for argument in "$@"; do
    printf ' %q' "$argument" >> "$MOCK_LOG"
done

printf '\n' >> "$MOCK_LOG"

if [[ "${1:-}" == "-genkeypair" ]]; then
    keystore_path=""

    while (( $# > 0 )); do
        case "$1" in
            -keystore)
                shift
                (( $# > 0 )) || exit 64
                keystore_path="$1"
                ;;
        esac

        shift
    done

    [[ -n "$keystore_path" ]] || exit 64

    printf 'mock keystore\n' > "$keystore_path"
    printf 'Generated mock key pair\n'
    exit 0
fi

cat <<'KEYSTORE'
Alias name: production
Entry type: PrivateKeyEntry
Owner: CN=TADK Release
Issuer: CN=TADK Release
Certificate fingerprints:
         SHA256: TEST_KEYSTORE_CERTIFICATE_DIGEST
KEYSTORE
MOCK_KEYTOOL

cat > "$MOCK_BIN/apksigner" <<'MOCK_APKSIGNER'
#!/usr/bin/env bash

set -Eeuo pipefail

printf 'apksigner' >> "$MOCK_LOG"

for argument in "$@"; do
    printf ' %q' "$argument" >> "$MOCK_LOG"
done

printf '\n' >> "$MOCK_LOG"

apk_path="${!#}"

if [[ "$apk_path" == *"unsigned.apk" ]]; then
    printf 'DOES NOT VERIFY\n' >&2
    exit 1
fi

cat <<'VERIFY'
Verifies
Verified using v1 scheme (JAR signing): false
Verified using v2 scheme (APK Signature Scheme v2): true
Signer #1 certificate DN: CN=TADK Test
Signer #1 certificate SHA-256 digest: TEST_CERTIFICATE_DIGEST
VERIFY
MOCK_APKSIGNER

cat > "$MOCK_BIN/sha256sum" <<'MOCK_SHA256SUM'
#!/usr/bin/env bash

printf 'TEST_APK_SHA256  %s\n' "$1"
MOCK_SHA256SUM

chmod +x \
    "$MOCK_BIN/keytool" \
    "$MOCK_BIN/apksigner" \
    "$MOCK_BIN/sha256sum"

export MOCK_LOG
export PATH="$MOCK_BIN:$PATH"

assert_equals() {
    if (( $# != 3 )); then
        fail "assert_equals 需要 EXPECTED、ACTUAL 和 MESSAGE"
    fi

    local expected="$1"
    local actual="$2"
    local message="$3"

    [[ "$actual" == "$expected" ]] ||
        fail "$message；期望：$expected；实际：$actual"
}

assert_file_contains() {
    if (( $# != 3 )); then
        fail "assert_file_contains 需要 FILE、NEEDLE 和 MESSAGE"
    fi

    local file_path="$1"
    local needle="$2"
    local message="$3"

    [[ -f "$file_path" ]] ||
        fail "$message；文件不存在：$file_path"

    grep -Fq -- "$needle" "$file_path" ||
        fail "$message"
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local value="$1"
    local expected="$2"
    local message="$3"

    [[ "$value" == *"$expected"* ]] ||
        fail "$message"
}

assert_failure() {
    local status="$1"
    local message="$2"

    (( status != 0 )) ||
        fail "$message"
}

printf 'TEST release help\n'

output="$(
    "$TADK_ROOT/bin/tadk" \
        release \
        --help \
        2>&1
)"

assert_contains \
    "$output" \
    "tadk release doctor" \
    "帮助应包含 doctor"

assert_contains \
    "$output" \
    "tadk release verify" \
    "帮助应包含 verify"

assert_contains \
    "$output" \
    "tadk release keygen" \
    "帮助应包含 keygen"

assert_contains \
    "$output" \
    "--storepass-env" \
    "keygen 帮助应说明密码环境变量"

printf 'PASS release help\n\n'

printf 'TEST release doctor succeeds\n'

output="$(
    "$TADK_ROOT/bin/tadk" \
        release \
        doctor \
        2>&1
)"

assert_contains \
    "$output" \
    "Release 签名验证环境可用" \
    "环境完整时 doctor 应成功"

assert_contains \
    "$output" \
    "keytool" \
    "doctor 应检查 keytool"

assert_contains \
    "$output" \
    "apksigner" \
    "doctor 应检查 apksigner"

printf 'PASS release doctor succeeds\n\n'

printf 'TEST verify explicit signed APK\n'

: > "$MOCK_LOG"

output="$(
    "$TADK_ROOT/bin/tadk" \
        release \
        verify \
        "$RELEASE_APK" \
        2>&1
)"

assert_contains \
    "$output" \
    "APK 签名有效" \
    "已签名 APK 应验证成功"

assert_contains \
    "$output" \
    "Signer #1 certificate DN" \
    "应显示证书信息"

assert_contains \
    "$output" \
    "SHA-256：TEST_APK_SHA256" \
    "应显示 APK SHA-256"

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "apksigner verify --verbose --print-certs $RELEASE_APK" \
    "应调用 apksigner 完整验证"

printf 'PASS verify explicit signed APK\n\n'

printf 'TEST verify latest project release APK\n'

cd "$MOCK_PROJECT"
rm -f "$UNSIGNED_APK"
: > "$MOCK_LOG"

output="$(
    "$TADK_ROOT/bin/tadk" \
        release \
        verify \
        2>&1
)"

assert_contains \
    "$output" \
    "$RELEASE_APK" \
    "未指定路径时应解析项目 Release APK"

assert_contains \
    "$output" \
    "APK 签名有效" \
    "项目 Release APK 应验证成功"

printf 'PASS verify latest project release APK\n\n'

printf 'TEST unsigned APK fails\n'

printf 'unsigned apk fixture\n' > "$UNSIGNED_APK"

set +e
output="$(
    "$TADK_ROOT/bin/tadk" \
        release \
        verify \
        "$UNSIGNED_APK" \
        2>&1
)"
status=$?
set -e

assert_failure \
    "$status" \
    "未签名 APK 应验证失败"

assert_contains \
    "$output" \
    "DOES NOT VERIFY" \
    "应保留 apksigner 原始错误"

assert_contains \
    "$output" \
    "APK 签名验证失败" \
    "应显示清晰失败信息"

printf 'PASS unsigned APK fails\n\n'

printf 'TEST missing APK fails\n'

set +e
output="$(
    "$TADK_ROOT/bin/tadk" \
        release \
        verify \
        "$TEST_ROOT/missing.apk" \
        2>&1
)"
status=$?
set -e

assert_failure \
    "$status" \
    "不存在的 APK 应失败"

assert_contains \
    "$output" \
    "APK 不存在" \
    "应说明 APK 不存在"

printf 'PASS missing APK fails\n\n'

printf 'TEST non-APK file fails\n'

TEXT_FILE="$TEST_ROOT/not-an-apk.txt"
printf 'text\n' > "$TEXT_FILE"

set +e
output="$(
    "$TADK_ROOT/bin/tadk" \
        release \
        verify \
        "$TEXT_FILE" \
        2>&1
)"
status=$?
set -e

assert_failure \
    "$status" \
    "非 APK 文件应失败"

assert_contains \
    "$output" \
    "目标文件不是 APK" \
    "应说明目标类型错误"

printf 'PASS non-APK file fails\n\n'

printf 'TEST unknown release action fails\n'

set +e
output="$(
    "$TADK_ROOT/bin/tadk" \
        release \
        unknown \
        2>&1
)"
status=$?
set -e

assert_failure \
    "$status" \
    "未知 release 操作应失败"

assert_contains \
    "$output" \
    "未知 release 操作" \
    "应说明未知操作"

printf 'PASS unknown release action fails\n\n'

printf 'TEST project config limits automatic APK resolution to module\n'

mkdir -p \
    "$MOCK_PROJECT/.tadk" \
    "$MOCK_PROJECT/other/build/outputs/apk/release"

cat > "$MOCK_PROJECT/.tadk/project.conf" <<'CONFIG'
version=1
module=app
variant=debug
CONFIG

OTHER_APK="$MOCK_PROJECT/other/build/outputs/apk/release/other-release.apk"
printf 'other signed apk fixture\n' > "$OTHER_APK"

touch "$RELEASE_APK"
sleep 1
touch "$OTHER_APK"

: > "$MOCK_LOG"

output="$(
    "$TADK_ROOT/bin/tadk" \
        release \
        verify \
        2>&1
)"

assert_contains \
    "$output" \
    "$RELEASE_APK" \
    "自动验证应使用配置模块中的 Release APK"

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "$RELEASE_APK" \
    "apksigner 应验证配置模块中的 APK"

if [[ "$calls" == *"$OTHER_APK"* ]]; then
    fail "不应验证其他模块中的 Release APK"
fi

printf 'PASS project config limits automatic APK resolution to module\n\n'


printf 'TEST release build compiles and verifies configured module\n'

: > "$MOCK_LOG"

output="$(
    "$TADK_ROOT/bin/tadk" \
        release \
        build \
        --clean \
        --no-cache \
        -- \
        --stacktrace \
        2>&1
)"

assert_contains \
    "$output" \
    "TADK Release Build" \
    "release build 应显示流程标题"

assert_contains \
    "$output" \
    "APK 签名有效" \
    "release build 应验证构建产物"

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "gradlew clean --console=plain --no-build-cache --stacktrace" \
    "release build 应先清理项目"

assert_contains \
    "$calls" \
    "gradlew :app:assembleRelease --console=plain --no-build-cache --stacktrace" \
    "release build 应构建配置模块的 Release APK"

assert_contains \
    "$calls" \
    "apksigner verify --verbose --print-certs $RELEASE_APK" \
    "release build 应验证配置模块的 Release APK"

gradle_line="$(
    grep -n '^gradlew ' "$MOCK_LOG" |
        head -n 1 |
        cut -d: -f1
)"

signer_line="$(
    grep -n '^apksigner ' "$MOCK_LOG" |
        head -n 1 |
        cut -d: -f1
)"

[[ -n "$gradle_line" && -n "$signer_line" ]] ||
    fail "应同时记录 Gradle 构建和签名验证"

(( gradle_line < signer_line )) ||
    fail "必须先完成构建，再执行签名验证"

printf 'PASS release build compiles and verifies configured module\n\n'

printf 'TEST release build rejects unsupported option\n'

set +e
output="$(
    "$TADK_ROOT/bin/tadk" \
        release \
        build \
        --unknown \
        2>&1
)"
command_status=$?
set -e

assert_failure \
    "$command_status" \
    "release build 未知选项应失败"

assert_contains \
    "$output" \
    "build 不支持参数" \
    "应说明 build 参数不受支持"

printf 'PASS release build rejects unsupported option\n\n'


printf 'TEST release keystore inspects selected alias securely\n'

KEYSTORE_FILE="$TEST_ROOT/release.jks"
printf 'keystore fixture\n' > "$KEYSTORE_FILE"

export TEST_STOREPASS='not-printed-secret'
: > "$MOCK_LOG"

output="$(
    "$TADK_ROOT/bin/tadk" \
        release \
        keystore \
        "$KEYSTORE_FILE" \
        --alias production \
        --storepass-env TEST_STOREPASS \
        2>&1
)"

assert_contains \
    "$output" \
    "TADK Release Keystore" \
    "keystore 应显示检查标题"

assert_contains \
    "$output" \
    "Alias name: production" \
    "keystore 应显示选定条目的证书信息"

assert_contains \
    "$output" \
    "TEST_KEYSTORE_CERTIFICATE_DIGEST" \
    "keystore 应保留 keytool 证书摘要"

assert_contains \
    "$output" \
    "SHA-256：TEST_APK_SHA256" \
    "keystore 应显示文件摘要"

if [[ "$output" == *"$TEST_STOREPASS"* ]]; then
    fail "keystore 输出不得包含密码"
fi

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "keytool -list -v -keystore $KEYSTORE_FILE -alias production -storepass:env TEST_STOREPASS" \
    "keystore 应通过环境变量名称传递密码"

if [[ "$calls" == *"$TEST_STOREPASS"* ]]; then
    fail "keytool 参数不得包含密码值"
fi

printf 'PASS release keystore inspects selected alias securely\n\n'

printf 'TEST release keystore rejects missing password environment\n'

unset MISSING_STOREPASS || true

set +e
output="$(
    "$TADK_ROOT/bin/tadk" \
        release \
        keystore \
        "$KEYSTORE_FILE" \
        --storepass-env MISSING_STOREPASS \
        2>&1
)"
command_status=$?
set -e

assert_failure \
    "$command_status" \
    "缺少密码环境变量时应失败"

assert_contains \
    "$output" \
    "环境变量未设置：MISSING_STOREPASS" \
    "应明确说明密码环境变量未设置"

printf 'PASS release keystore rejects missing password environment\n\n'

printf 'TEST release keystore rejects missing file\n'

set +e
output="$(
    "$TADK_ROOT/bin/tadk" \
        release \
        keystore \
        "$TEST_ROOT/missing.jks" \
        2>&1
)"
command_status=$?
set -e

assert_failure \
    "$command_status" \
    "不存在的 keystore 应失败"

assert_contains \
    "$output" \
    "keystore 不存在" \
    "应说明 keystore 文件不存在"

printf 'PASS release keystore rejects missing file\n\n'


printf 'TEST release keystore accepts single-character environment name\n'

export P='single-character-secret'
: > "$MOCK_LOG"

output="$(
    "$TADK_ROOT/bin/tadk" \
        release \
        keystore \
        "$KEYSTORE_FILE" \
        --storepass-env P \
        2>&1
)"

assert_contains \
    "$output" \
    "keystore 可访问" \
    "单字符环境变量名称应合法"

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "-storepass:env P" \
    "应将单字符环境变量名称传给 keytool"

if [[ "$output" == *"$P"* ]]; then
    fail "输出不得包含单字符环境变量中的密码值"
fi

unset P

printf 'PASS release keystore accepts single-character environment name\n\n'

printf 'TEST release keystore rejects invalid environment name\n'

set +e
output="$(
    "$TADK_ROOT/bin/tadk" \
        release \
        keystore \
        "$KEYSTORE_FILE" \
        --storepass-env 'AB-CD' \
        2>&1
)"
command_status=$?
set -e

assert_failure \
    "$command_status" \
    "包含连字符的环境变量名称应失败"

assert_contains \
    "$output" \
    "无效的环境变量名称：AB-CD" \
    "应明确拒绝非法环境变量名称"

printf 'PASS release keystore rejects invalid environment name\n\n'


printf 'TEST release setup generates Kotlin signing skeleton\n'

SETUP_KOTLIN="$TEST_ROOT/setup-kotlin"

mkdir -p \
    "$SETUP_KOTLIN/app" \
    "$SETUP_KOTLIN/.tadk"

cat > "$SETUP_KOTLIN/gradlew" <<'GRADLEW'
#!/usr/bin/env bash
exit 0
GRADLEW

chmod +x "$SETUP_KOTLIN/gradlew"

cat > "$SETUP_KOTLIN/settings.gradle.kts" <<'SETTINGS'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
SETTINGS

cat > "$SETUP_KOTLIN/app/build.gradle.kts" <<'BUILD'
plugins {
    id("com.android.application")
}

android {
    namespace = "dev.tadk.setup"
}
BUILD

cat > "$SETUP_KOTLIN/.tadk/project.conf" <<'CONFIG'
version=1
module=app
variant=debug
CONFIG

(
    cd "$SETUP_KOTLIN"

    "$TADK_ROOT/bin/tadk" \
        release \
        setup \
        >/dev/null
)

[[ -f "$SETUP_KOTLIN/keystore.properties.example" ]] ||
    fail "应生成 keystore.properties.example"

[[ -f "$SETUP_KOTLIN/.tadk/release-signing-snippet.gradle.kts" ]] ||
    fail "Kotlin 项目应生成 Kotlin DSL 签名片段"

assert_file_contains \
    "$SETUP_KOTLIN/keystore.properties.example" \
    "storePassword=CHANGE_ME" \
    "properties 示例不得包含真实密码"

assert_file_contains \
    "$SETUP_KOTLIN/.tadk/release-signing-snippet.gradle.kts" \
    'signingConfigs {' \
    "Kotlin 签名片段应包含 signingConfigs"

assert_file_contains \
    "$SETUP_KOTLIN/.gitignore" \
    "/keystore.properties" \
    "应忽略本地签名属性文件"

assert_file_contains \
    "$SETUP_KOTLIN/.gitignore" \
    "/release.jks" \
    "应忽略默认 keystore"

printf 'PASS release setup generates Kotlin signing skeleton\n\n'

printf 'TEST release setup is idempotent for gitignore\n'

(
    cd "$SETUP_KOTLIN"

    "$TADK_ROOT/bin/tadk" \
        release \
        setup \
        --force \
        >/dev/null
)

ignore_count="$(
    grep -Fxc \
        "# TADK Release signing" \
        "$SETUP_KOTLIN/.gitignore"
)"

assert_equals \
    "1" \
    "$ignore_count" \
    "重复 setup 不应重复写入 gitignore"

printf 'PASS release setup is idempotent for gitignore\n\n'

printf 'TEST release setup detects Groovy DSL\n'

SETUP_GROOVY="$TEST_ROOT/setup-groovy"

mkdir -p "$SETUP_GROOVY/mobile"

cat > "$SETUP_GROOVY/gradlew" <<'GRADLEW'
#!/usr/bin/env bash
exit 0
GRADLEW

chmod +x "$SETUP_GROOVY/gradlew"

cat > "$SETUP_GROOVY/settings.gradle" <<'SETTINGS'
include ':mobile'
SETTINGS

cat > "$SETUP_GROOVY/mobile/build.gradle" <<'BUILD'
plugins {
    id 'com.android.application'
}

android {
    namespace 'dev.tadk.groovy'
}
BUILD

(
    cd "$SETUP_GROOVY"

    "$TADK_ROOT/bin/tadk" \
        release \
        setup \
        --module mobile \
        >/dev/null
)

[[ -f "$SETUP_GROOVY/.tadk/release-signing-snippet.gradle" ]] ||
    fail "Groovy 项目应生成 Groovy DSL 签名片段"

[[ ! -e "$SETUP_GROOVY/.tadk/release-signing-snippet.gradle.kts" ]] ||
    fail "Groovy 项目不应生成 Kotlin DSL 签名片段"

assert_file_contains \
    "$SETUP_GROOVY/.tadk/release-signing-snippet.gradle" \
    "signingConfigs {" \
    "Groovy 签名片段应包含 signingConfigs"

printf 'PASS release setup detects Groovy DSL\n\n'

printf 'TEST release setup refuses template overwrite\n'

set +e
output="$(
    cd "$SETUP_KOTLIN"

    "$TADK_ROOT/bin/tadk" \
        release \
        setup \
        2>&1
)"
command_status=$?
set -e

assert_failure \
    "$command_status" \
    "未指定 --force 时不应覆盖已有模板"

assert_contains \
    "$output" \
    "文件已存在，不会覆盖" \
    "应说明 setup 拒绝覆盖已有模板"

printf 'PASS release setup refuses template overwrite\n\n'


printf 'TEST release init writes protected signing properties\n'

INIT_PROJECT="$TEST_ROOT/release-init"

mkdir -p "$INIT_PROJECT/app"

cat > "$INIT_PROJECT/gradlew" <<'GRADLEW'
#!/usr/bin/env bash
exit 0
GRADLEW

chmod +x "$INIT_PROJECT/gradlew"

cat > "$INIT_PROJECT/settings.gradle.kts" <<'SETTINGS'
include(":app")
SETTINGS

cat > "$INIT_PROJECT/app/build.gradle.kts" <<'BUILD'
plugins {
    id("com.android.application")
}
BUILD

INIT_KEYSTORE="$INIT_PROJECT/release.jks"
printf 'keystore fixture\n' > "$INIT_KEYSTORE"

export INIT_STOREPASS='store-secret'
export INIT_KEYPASS='key-secret'

: > "$MOCK_LOG"

output="$(
    cd "$INIT_PROJECT"

    "$TADK_ROOT/bin/tadk" \
        release \
        init \
        --keystore "$INIT_KEYSTORE" \
        --alias production \
        --storepass-env INIT_STOREPASS \
        --keypass-env INIT_KEYPASS \
        2>&1
)"

INIT_PROPERTIES="$INIT_PROJECT/keystore.properties"

[[ -f "$INIT_PROPERTIES" ]] ||
    fail "release init 应创建 keystore.properties"

assert_file_contains \
    "$INIT_PROPERTIES" \
    "storeFile=$INIT_KEYSTORE" \
    "配置应保存绝对 keystore 路径"

assert_file_contains \
    "$INIT_PROPERTIES" \
    "keyAlias=production" \
    "配置应保存 alias"

assert_file_contains \
    "$INIT_PROPERTIES" \
    "storePassword=$INIT_STOREPASS" \
    "配置应保存 store 密码"

assert_file_contains \
    "$INIT_PROPERTIES" \
    "keyPassword=$INIT_KEYPASS" \
    "配置应保存 key 密码"

permissions="$(stat -c '%a' "$INIT_PROPERTIES")"

assert_equals \
    "600" \
    "$permissions" \
    "keystore.properties 权限应为 600"

if [[ "$output" == *"$INIT_STOREPASS"* ||
      "$output" == *"$INIT_KEYPASS"* ]]; then
    fail "release init 输出不得包含密码"
fi

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "-storepass:env INIT_STOREPASS" \
    "keytool 应通过环境变量读取 store 密码"

if [[ "$calls" == *"-keypass"* ]]; then
    fail "keytool -list 不得接收不支持的 -keypass 参数"
fi

if [[ "$calls" == *"$INIT_STOREPASS"* ||
      "$calls" == *"$INIT_KEYPASS"* ]]; then
    fail "keytool 参数不得包含密码值"
fi

printf 'PASS release init writes protected signing properties\n\n'

printf 'TEST release init refuses overwrite\n'

set +e
output="$(
    cd "$INIT_PROJECT"

    "$TADK_ROOT/bin/tadk" \
        release \
        init \
        --keystore "$INIT_KEYSTORE" \
        --alias production \
        --storepass-env INIT_STOREPASS \
        2>&1
)"
command_status=$?
set -e

assert_failure \
    "$command_status" \
    "release init 默认不应覆盖已有配置"

assert_contains \
    "$output" \
    "文件已存在，不会覆盖" \
    "release init 应说明拒绝覆盖"

printf 'PASS release init refuses overwrite\n\n'

printf 'TEST release init validates without writing\n'

VALIDATE_PROJECT="$TEST_ROOT/release-init-validate"

mkdir -p "$VALIDATE_PROJECT/app"

cp "$INIT_PROJECT/gradlew" "$VALIDATE_PROJECT/gradlew"
cp "$INIT_PROJECT/settings.gradle.kts" \
    "$VALIDATE_PROJECT/settings.gradle.kts"
cp "$INIT_PROJECT/app/build.gradle.kts" \
    "$VALIDATE_PROJECT/app/build.gradle.kts"

chmod +x "$VALIDATE_PROJECT/gradlew"

output="$(
    cd "$VALIDATE_PROJECT"

    "$TADK_ROOT/bin/tadk" \
        release \
        init \
        --keystore "$INIT_KEYSTORE" \
        --alias production \
        --storepass-env INIT_STOREPASS \
        --validate-only \
        2>&1
)"

assert_contains \
    "$output" \
    "keystore 密码和 alias 校验成功" \
    "validate-only 应报告实际完成的校验"

[[ ! -e "$VALIDATE_PROJECT/keystore.properties" ]] ||
    fail "validate-only 不得创建 keystore.properties"

printf 'PASS release init validates without writing\n\n'


printf 'TEST release init preserves keytool failure status\n'

FAIL_PROJECT="$TEST_ROOT/release-init-keytool-failure"

mkdir -p "$FAIL_PROJECT/app"

cp "$INIT_PROJECT/gradlew" "$FAIL_PROJECT/gradlew"
cp "$INIT_PROJECT/settings.gradle.kts" \
    "$FAIL_PROJECT/settings.gradle.kts"
cp "$INIT_PROJECT/app/build.gradle.kts" \
    "$FAIL_PROJECT/app/build.gradle.kts"

chmod +x "$FAIL_PROJECT/gradlew"

export MOCK_KEYTOOL_FAIL=true

set +e
output="$(
    cd "$FAIL_PROJECT"

    "$TADK_ROOT/bin/tadk" \
        release \
        init \
        --keystore "$INIT_KEYSTORE" \
        --alias production \
        --storepass-env INIT_STOREPASS \
        2>&1
)"
command_status=$?
set -e

unset MOCK_KEYTOOL_FAIL

assert_equals \
    "23" \
    "$command_status" \
    "release init 应保留 keytool 失败状态"

assert_contains \
    "$output" \
    "keystore 密码错误、alias 不存在或 keystore 无法读取" \
    "release init 应报告 keystore 校验失败"

[[ ! -e "$FAIL_PROJECT/keystore.properties" ]] ||
    fail "keytool 校验失败后不得写入签名配置"

printf 'PASS release init preserves keytool failure status\n\n'


printf 'TEST release keygen creates protected keystore\n'

KEYGEN_DIRECTORY="$TEST_ROOT/release-keygen"
KEYGEN_KEYSTORE="$KEYGEN_DIRECTORY/production.p12"

mkdir -p "$KEYGEN_DIRECTORY"

export KEYGEN_STOREPASS='store-secret-123'
export KEYGEN_KEYPASS='store-secret-123'

: > "$MOCK_LOG"

output="$(
    "$TADK_ROOT/bin/tadk" \
        release \
        keygen \
        --keystore "$KEYGEN_KEYSTORE" \
        --alias production \
        --dname "CN=TADK Test, O=TADK, C=CA" \
        --storepass-env KEYGEN_STOREPASS \
        --keypass-env KEYGEN_KEYPASS \
        --keyalg RSA \
        --keysize 3072 \
        --validity 3650 \
        --storetype PKCS12 \
        2>&1
)"

[[ -f "$KEYGEN_KEYSTORE" ]] ||
    fail "release keygen 应创建 keystore"

permissions="$(stat -c '%a' "$KEYGEN_KEYSTORE")"

assert_equals \
    "600" \
    "$permissions" \
    "生成的 keystore 权限应为 600"

assert_contains \
    "$output" \
    "已生成：$KEYGEN_KEYSTORE" \
    "release keygen 应报告生成路径"

assert_contains \
    "$output" \
    "算法：RSA 3072-bit" \
    "release keygen 应显示算法信息"

if [[ "$output" == *"$KEYGEN_STOREPASS"* ||
      "$output" == *"$KEYGEN_KEYPASS"* ]]; then
    fail "release keygen 输出不得包含密码值"
fi

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "keytool -genkeypair" \
    "release keygen 应调用 keytool -genkeypair"

assert_contains \
    "$calls" \
    "-keystore $KEYGEN_KEYSTORE.tadk." \
    "keytool 应先写入临时 keystore"

assert_contains \
    "$calls" \
    "-alias production" \
    "keytool 应接收签名 alias"

assert_contains \
    "$calls" \
    "-keyalg RSA" \
    "keytool 应接收密钥算法"

assert_contains \
    "$calls" \
    "-keysize 3072" \
    "keytool 应接收密钥长度"

assert_contains \
    "$calls" \
    "-validity 3650" \
    "keytool 应接收证书有效期"

assert_contains \
    "$calls" \
    "-storetype PKCS12" \
    "keytool 应接收 keystore 类型"

assert_contains \
    "$calls" \
    "-storepass:env KEYGEN_STOREPASS" \
    "store 密码应通过环境变量传递"

assert_contains \
    "$calls" \
    "-keypass:env KEYGEN_KEYPASS" \
    "key 密码应通过环境变量传递"

if [[ "$calls" == *"$KEYGEN_STOREPASS"* ||
      "$calls" == *"$KEYGEN_KEYPASS"* ]]; then
    fail "keytool 参数不得包含密码值"
fi

printf 'PASS release keygen creates protected keystore\n\n'

printf 'TEST release keygen refuses overwrite by default\n'

printf 'original keystore\n' > "$KEYGEN_KEYSTORE"

set +e
output="$(
    "$TADK_ROOT/bin/tadk" \
        release \
        keygen \
        --keystore "$KEYGEN_KEYSTORE" \
        --alias production \
        --dname "CN=TADK Test, O=TADK, C=CA" \
        --storepass-env KEYGEN_STOREPASS \
        2>&1
)"
command_status=$?
set -e

assert_failure \
    "$command_status" \
    "release keygen 默认不应覆盖已有 keystore"

assert_contains \
    "$output" \
    "keystore 已存在，不会覆盖" \
    "release keygen 应说明拒绝覆盖"

assert_file_contains \
    "$KEYGEN_KEYSTORE" \
    "original keystore" \
    "拒绝覆盖时应保留原 keystore"

printf 'PASS release keygen refuses overwrite by default\n\n'

printf 'TEST release keygen force replaces atomically\n'

output="$(
    "$TADK_ROOT/bin/tadk" \
        release \
        keygen \
        --keystore "$KEYGEN_KEYSTORE" \
        --alias production \
        --dname "CN=TADK Test, O=TADK, C=CA" \
        --storepass-env KEYGEN_STOREPASS \
        --force \
        2>&1
)"

assert_file_contains \
    "$KEYGEN_KEYSTORE" \
    "mock keystore" \
    "--force 应在生成成功后替换原 keystore"

assert_contains \
    "$output" \
    "覆盖已有 keystore：true" \
    "--force 输出应说明覆盖模式"

printf 'PASS release keygen force replaces atomically\n\n'

printf 'TEST release keygen preserves original on keytool failure\n'

printf 'valuable original keystore\n' > "$KEYGEN_KEYSTORE"

export MOCK_KEYTOOL_FAIL=true

set +e
output="$(
    "$TADK_ROOT/bin/tadk" \
        release \
        keygen \
        --keystore "$KEYGEN_KEYSTORE" \
        --alias production \
        --dname "CN=TADK Test, O=TADK, C=CA" \
        --storepass-env KEYGEN_STOREPASS \
        --force \
        2>&1
)"
command_status=$?
set -e

unset MOCK_KEYTOOL_FAIL

assert_equals \
    "23" \
    "$command_status" \
    "release keygen 应保留 keytool 失败状态"

assert_contains \
    "$output" \
    "keystore 生成失败" \
    "release keygen 应报告生成失败"

assert_file_contains \
    "$KEYGEN_KEYSTORE" \
    "valuable original keystore" \
    "keytool 失败时不得破坏原 keystore"

if compgen -G "$KEYGEN_KEYSTORE.tadk.*" >/dev/null; then
    fail "keytool 失败后不得残留临时 keystore"
fi

printf 'PASS release keygen preserves original on keytool failure\n\n'

printf 'TEST release keygen rejects duplicate default option\n'

set +e
output="$(
    "$TADK_ROOT/bin/tadk" \
        release \
        keygen \
        --keystore "$TEST_ROOT/duplicate.p12" \
        --alias production \
        --dname "CN=TADK Test, O=TADK, C=CA" \
        --storepass-env KEYGEN_STOREPASS \
        --keysize 4096 \
        --keysize 4096 \
        2>&1
)"
command_status=$?
set -e

assert_equals \
    "64" \
    "$command_status" \
    "重复指定默认值选项也应返回用法错误"

assert_contains \
    "$output" \
    "--keysize 不能重复指定" \
    "应识别重复的默认 keysize"

printf 'PASS release keygen rejects duplicate default option\n\n'

printf 'TEST release keygen rejects separate PKCS12 key password\n'

PKCS12_MISMATCH="$TEST_ROOT/pkcs12-password-mismatch.p12"

export KEYGEN_DIFFERENT_KEYPASS='different-key-secret'

: > "$MOCK_LOG"

set +e
output="$(
    "$TADK_ROOT/bin/tadk" \
        release \
        keygen \
        --keystore "$PKCS12_MISMATCH" \
        --alias production \
        --dname "CN=TADK Test, O=TADK, C=CA" \
        --storepass-env KEYGEN_STOREPASS \
        --keypass-env KEYGEN_DIFFERENT_KEYPASS \
        --storetype PKCS12 \
        2>&1
)"
command_status=$?
set -e

unset KEYGEN_DIFFERENT_KEYPASS

assert_equals \
    "64" \
    "$command_status" \
    "PKCS12 使用不同 key 密码时应返回用法错误"

assert_contains \
    "$output" \
    "PKCS12 不支持独立的 key 密码" \
    "应解释 PKCS12 密码限制"

[[ ! -e "$PKCS12_MISMATCH" ]] ||
    fail "密码配置无效时不得生成 keystore"

calls="$(cat "$MOCK_LOG")"

if [[ "$calls" == *"keytool"* ]]; then
    fail "PKCS12 密码不一致时不应调用 keytool"
fi

printf 'PASS release keygen rejects separate PKCS12 key password\n\n'

unset KEYGEN_STOREPASS
unset KEYGEN_KEYPASS


printf 'TEST release apply configures Kotlin DSL project\n'

APPLY_KOTLIN_PROJECT="$TEST_ROOT/release-apply-kotlin"
APPLY_KOTLIN_BUILD="$APPLY_KOTLIN_PROJECT/app/build.gradle.kts"

mkdir -p "$APPLY_KOTLIN_PROJECT/app"

cat > "$APPLY_KOTLIN_PROJECT/gradlew" <<'GRADLEW'
#!/usr/bin/env bash
exit 0
GRADLEW

cat > "$APPLY_KOTLIN_PROJECT/settings.gradle.kts" <<'SETTINGS'
rootProject.name = "ApplyKotlinFixture"
include(":app")
SETTINGS

cat > "$APPLY_KOTLIN_BUILD" <<'BUILD'
plugins {
    id("com.android.application")
}

android {
    namespace = "com.example.kotlin"
    compileSdk = 36
}
BUILD

chmod +x "$APPLY_KOTLIN_PROJECT/gradlew"

original_mode="$(stat -c '%a' "$APPLY_KOTLIN_BUILD")"

output="$(
    cd "$APPLY_KOTLIN_PROJECT"

    "$TADK_ROOT/bin/tadk" \
        release \
        apply \
        2>&1
)"

assert_contains \
    "$output" \
    "已应用 Release 签名配置" \
    "Kotlin DSL 项目应成功应用签名配置"

assert_file_contains \
    "$APPLY_KOTLIN_BUILD" \
    "// TADK Release signing begin" \
    "Kotlin 构建文件应包含开始标记"

assert_file_contains \
    "$APPLY_KOTLIN_BUILD" \
    'java.util.Properties()' \
    "Kotlin 配置应加载 keystore.properties"

assert_file_contains \
    "$APPLY_KOTLIN_BUILD" \
    'maybeCreate("release")' \
    "Kotlin 配置应创建或复用 release signingConfig"

assert_file_contains \
    "$APPLY_KOTLIN_BUILD" \
    'signingConfigs.getByName("release")' \
    "Kotlin release build type 应使用签名配置"

updated_mode="$(stat -c '%a' "$APPLY_KOTLIN_BUILD")"

assert_equals \
    "$original_mode" \
    "$updated_mode" \
    "release apply 应保留 Gradle 文件权限"

begin_count="$(
    grep -Fxc \
        "// TADK Release signing begin" \
        "$APPLY_KOTLIN_BUILD"
)"

end_count="$(
    grep -Fxc \
        "// TADK Release signing end" \
        "$APPLY_KOTLIN_BUILD"
)"

assert_equals \
    "1" \
    "$begin_count" \
    "Kotlin 配置只能包含一个开始标记"

assert_equals \
    "1" \
    "$end_count" \
    "Kotlin 配置只能包含一个结束标记"

printf 'PASS release apply configures Kotlin DSL project\n\n'

printf 'TEST release apply check and idempotency\n'

before_hash="$(sha256sum "$APPLY_KOTLIN_BUILD" | awk '{print $1}')"

output="$(
    cd "$APPLY_KOTLIN_PROJECT"

    "$TADK_ROOT/bin/tadk" \
        release \
        apply \
        --check \
        2>&1
)"

assert_contains \
    "$output" \
    "TADK Release 签名配置已应用" \
    "--check 应确认已有配置"

output="$(
    cd "$APPLY_KOTLIN_PROJECT"

    "$TADK_ROOT/bin/tadk" \
        release \
        apply \
        2>&1
)"

assert_contains \
    "$output" \
    "已存在，无需修改" \
    "重复 apply 应保持幂等"

after_hash="$(sha256sum "$APPLY_KOTLIN_BUILD" | awk '{print $1}')"

assert_equals \
    "$before_hash" \
    "$after_hash" \
    "幂等 apply 不得修改 Gradle 文件"

printf 'PASS release apply check and idempotency\n\n'

printf 'TEST release apply force refreshes managed block\n'

python - "$APPLY_KOTLIN_BUILD" <<'PY_EDIT'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
text = text.replace(
    'val tadkReleaseKeystoreFile =',
    '// stale managed content\nval tadkReleaseKeystoreFile =',
    1,
)
path.write_text(text)
PY_EDIT

assert_file_contains \
    "$APPLY_KOTLIN_BUILD" \
    "stale managed content" \
    "测试夹具应包含旧 TADK 内容"

output="$(
    cd "$APPLY_KOTLIN_PROJECT"

    "$TADK_ROOT/bin/tadk" \
        release \
        apply \
        --force \
        2>&1
)"

assert_contains \
    "$output" \
    "已应用 Release 签名配置" \
    "--force 应重新生成 TADK 配置块"

if grep -Fq \
    "stale managed content" \
    "$APPLY_KOTLIN_BUILD"; then
    fail "--force 应移除旧 TADK 配置块内容"
fi

begin_count="$(
    grep -Fxc \
        "// TADK Release signing begin" \
        "$APPLY_KOTLIN_BUILD"
)"

assert_equals \
    "1" \
    "$begin_count" \
    "--force 后仍只能存在一个 TADK 配置块"

printf 'PASS release apply force refreshes managed block\n\n'

printf 'TEST release apply configures Groovy DSL project\n'

APPLY_GROOVY_PROJECT="$TEST_ROOT/release-apply-groovy"
APPLY_GROOVY_BUILD="$APPLY_GROOVY_PROJECT/mobile/build.gradle"

mkdir -p "$APPLY_GROOVY_PROJECT/mobile"

cat > "$APPLY_GROOVY_PROJECT/gradlew" <<'GRADLEW'
#!/usr/bin/env bash
exit 0
GRADLEW

cat > "$APPLY_GROOVY_PROJECT/settings.gradle" <<'SETTINGS'
rootProject.name = "ApplyGroovyFixture"
include ":mobile"
SETTINGS

cat > "$APPLY_GROOVY_BUILD" <<'BUILD'
plugins {
    id "com.android.application"
}

android {
    namespace "com.example.groovy"
    compileSdk 36
}
BUILD

mkdir -p "$APPLY_GROOVY_PROJECT/.tadk"

cat > "$APPLY_GROOVY_PROJECT/.tadk/project.conf" <<'CONFIG'
version=1
module=mobile
variant=debug
CONFIG

chmod +x "$APPLY_GROOVY_PROJECT/gradlew"

output="$(
    cd "$APPLY_GROOVY_PROJECT"

    "$TADK_ROOT/bin/tadk" \
        release \
        apply \
        2>&1
)"

assert_contains \
    "$output" \
    "Gradle DSL：groovy" \
    "应检测 Groovy DSL"

assert_file_contains \
    "$APPLY_GROOVY_BUILD" \
    "new Properties()" \
    "Groovy 配置应加载 properties"

assert_file_contains \
    "$APPLY_GROOVY_BUILD" \
    'maybeCreate("release")' \
    "Groovy 配置应创建或复用 release signingConfig"

assert_file_contains \
    "$APPLY_GROOVY_BUILD" \
    "signingConfig signingConfigs.release" \
    "Groovy release build type 应使用签名配置"

printf 'PASS release apply configures Groovy DSL project\n\n'

printf 'TEST release apply refuses unmanaged signing config\n'

APPLY_EXISTING_PROJECT="$TEST_ROOT/release-apply-existing"
APPLY_EXISTING_BUILD="$APPLY_EXISTING_PROJECT/app/build.gradle.kts"

mkdir -p "$APPLY_EXISTING_PROJECT/app"

cp "$APPLY_KOTLIN_PROJECT/gradlew" \
    "$APPLY_EXISTING_PROJECT/gradlew"

cp "$APPLY_KOTLIN_PROJECT/settings.gradle.kts" \
    "$APPLY_EXISTING_PROJECT/settings.gradle.kts"

cat > "$APPLY_EXISTING_BUILD" <<'BUILD'
plugins {
    id("com.android.application")
}

android {
    signingConfigs {
        create("release") {
            keyAlias = "existing"
        }
    }
}
BUILD

chmod +x "$APPLY_EXISTING_PROJECT/gradlew"

existing_hash="$(
    sha256sum "$APPLY_EXISTING_BUILD" |
        awk '{print $1}'
)"

set +e
output="$(
    cd "$APPLY_EXISTING_PROJECT"

    "$TADK_ROOT/bin/tadk" \
        release \
        apply \
        2>&1
)"
command_status=$?
set -e

assert_failure \
    "$command_status" \
    "已有非 TADK signingConfig 时应拒绝修改"

assert_contains \
    "$output" \
    "检测到已有 signingConfig，拒绝自动修改" \
    "应说明拒绝已有签名配置"

current_hash="$(
    sha256sum "$APPLY_EXISTING_BUILD" |
        awk '{print $1}'
)"

assert_equals \
    "$existing_hash" \
    "$current_hash" \
    "拒绝操作时不得修改 Gradle 文件"

printf 'PASS release apply refuses unmanaged signing config\n\n'

printf 'TEST release apply rejects damaged markers\n'

APPLY_DAMAGED_PROJECT="$TEST_ROOT/release-apply-damaged"
APPLY_DAMAGED_BUILD="$APPLY_DAMAGED_PROJECT/app/build.gradle.kts"

mkdir -p "$APPLY_DAMAGED_PROJECT/app"

cp "$APPLY_KOTLIN_PROJECT/gradlew" \
    "$APPLY_DAMAGED_PROJECT/gradlew"

cp "$APPLY_KOTLIN_PROJECT/settings.gradle.kts" \
    "$APPLY_DAMAGED_PROJECT/settings.gradle.kts"

cat > "$APPLY_DAMAGED_BUILD" <<'BUILD'
plugins {
    id("com.android.application")
}

// TADK Release signing end
android {
    namespace = "com.example.damaged"
}
// TADK Release signing begin
BUILD

chmod +x "$APPLY_DAMAGED_PROJECT/gradlew"

damaged_hash="$(
    sha256sum "$APPLY_DAMAGED_BUILD" |
        awk '{print $1}'
)"

set +e
output="$(
    cd "$APPLY_DAMAGED_PROJECT"

    "$TADK_ROOT/bin/tadk" \
        release \
        apply \
        --force \
        2>&1
)"
command_status=$?
set -e

assert_failure \
    "$command_status" \
    "标记顺序损坏时应拒绝修改"

assert_contains \
    "$output" \
    "标记不完整、重复或顺序错误" \
    "应说明 TADK 标记损坏"

current_hash="$(
    sha256sum "$APPLY_DAMAGED_BUILD" |
        awk '{print $1}'
)"

assert_equals \
    "$damaged_hash" \
    "$current_hash" \
    "标记损坏时不得修改 Gradle 文件"

printf 'PASS release apply rejects damaged markers\n\n'

printf 'TEST release apply check fails before configuration\n'

APPLY_UNCONFIGURED_PROJECT="$TEST_ROOT/release-apply-unconfigured"

mkdir -p "$APPLY_UNCONFIGURED_PROJECT/app"

cp "$APPLY_KOTLIN_PROJECT/gradlew" \
    "$APPLY_UNCONFIGURED_PROJECT/gradlew"

cp "$APPLY_KOTLIN_PROJECT/settings.gradle.kts" \
    "$APPLY_UNCONFIGURED_PROJECT/settings.gradle.kts"

cat > "$APPLY_UNCONFIGURED_PROJECT/app/build.gradle.kts" <<'BUILD'
plugins {
    id("com.android.application")
}

android {
    namespace = "com.example.unconfigured"
}
BUILD

chmod +x "$APPLY_UNCONFIGURED_PROJECT/gradlew"

set +e
output="$(
    cd "$APPLY_UNCONFIGURED_PROJECT"

    "$TADK_ROOT/bin/tadk" \
        release \
        apply \
        --check \
        2>&1
)"
command_status=$?
set -e

assert_failure \
    "$command_status" \
    "未应用配置时 --check 应失败"

assert_contains \
    "$output" \
    "TADK Release 签名配置尚未应用" \
    "--check 应说明配置尚未应用"

printf 'PASS release apply check fails before configuration\n\n'


printf 'TEST release bootstrap completes signing initialization\n'

BOOTSTRAP_PROJECT="$TEST_ROOT/release-bootstrap"
BOOTSTRAP_BUILD="$BOOTSTRAP_PROJECT/app/build.gradle.kts"
BOOTSTRAP_KEYSTORE="$BOOTSTRAP_PROJECT/production.p12"

mkdir -p "$BOOTSTRAP_PROJECT/app"

cat > "$BOOTSTRAP_PROJECT/gradlew" <<'GRADLEW'
#!/usr/bin/env bash
exit 0
GRADLEW

cat > "$BOOTSTRAP_PROJECT/settings.gradle.kts" <<'SETTINGS'
rootProject.name = "BootstrapFixture"
include(":app")
SETTINGS

cat > "$BOOTSTRAP_BUILD" <<'BUILD'
plugins {
    id("com.android.application")
}

android {
    namespace = "com.example.bootstrap"
    compileSdk = 36
}
BUILD

chmod +x "$BOOTSTRAP_PROJECT/gradlew"

export BOOTSTRAP_STOREPASS='bootstrap-secret-123'
export BOOTSTRAP_KEYPASS='bootstrap-secret-123'

: > "$MOCK_LOG"

output="$(
    cd "$BOOTSTRAP_PROJECT"

    "$TADK_ROOT/bin/tadk" \
        release \
        bootstrap \
        --keystore "$BOOTSTRAP_KEYSTORE" \
        --alias production \
        --dname "CN=TADK Bootstrap, O=TADK, C=CA" \
        --storepass-env BOOTSTRAP_STOREPASS \
        --keypass-env BOOTSTRAP_KEYPASS \
        --module app \
        --keysize 3072 \
        --validity 3650 \
        --storetype PKCS12 \
        2>&1
)"

assert_contains \
    "$output" \
    "Bootstrap：生成 keystore" \
    "bootstrap 应执行 keygen 步骤"

assert_contains \
    "$output" \
    "Bootstrap：生成签名配置骨架" \
    "bootstrap 应执行 setup 步骤"

assert_contains \
    "$output" \
    "Bootstrap：创建本地签名配置" \
    "bootstrap 应执行 init 步骤"

assert_contains \
    "$output" \
    "Bootstrap：应用 Gradle 签名配置" \
    "bootstrap 应执行 apply 步骤"

assert_contains \
    "$output" \
    "Release 签名初始化已完成" \
    "bootstrap 应报告完整初始化成功"

if [[ "$output" == *"$BOOTSTRAP_STOREPASS"* ||
      "$output" == *"$BOOTSTRAP_KEYPASS"* ]]; then
    fail "bootstrap 输出不得泄漏密码值"
fi

[[ -f "$BOOTSTRAP_KEYSTORE" ]] ||
    fail "bootstrap 应生成 keystore"

permissions="$(stat -c '%a' "$BOOTSTRAP_KEYSTORE")"

assert_equals \
    "600" \
    "$permissions" \
    "bootstrap 生成的 keystore 权限应为 600"

[[ -f "$BOOTSTRAP_PROJECT/keystore.properties.example" ]] ||
    fail "bootstrap 应生成 keystore.properties.example"

[[ -f "$BOOTSTRAP_PROJECT/.tadk/release-signing-snippet.gradle.kts" ]] ||
    fail "bootstrap 应生成 Kotlin DSL 签名片段"

[[ -f "$BOOTSTRAP_PROJECT/keystore.properties" ]] ||
    fail "bootstrap 应生成 keystore.properties"

permissions="$(
    stat -c '%a' \
        "$BOOTSTRAP_PROJECT/keystore.properties"
)"

assert_equals \
    "600" \
    "$permissions" \
    "bootstrap 生成的 keystore.properties 权限应为 600"

assert_file_contains \
    "$BOOTSTRAP_PROJECT/keystore.properties" \
    "storeFile=$BOOTSTRAP_KEYSTORE" \
    "本地配置应引用生成的 keystore"

assert_file_contains \
    "$BOOTSTRAP_PROJECT/keystore.properties" \
    "keyAlias=production" \
    "本地配置应写入 alias"

assert_file_contains \
    "$BOOTSTRAP_PROJECT/keystore.properties" \
    "storePassword=$BOOTSTRAP_STOREPASS" \
    "本地配置应写入 store 密码"

assert_file_contains \
    "$BOOTSTRAP_PROJECT/keystore.properties" \
    "keyPassword=$BOOTSTRAP_KEYPASS" \
    "本地配置应写入 key 密码"

assert_file_contains \
    "$BOOTSTRAP_BUILD" \
    "// TADK Release signing begin" \
    "bootstrap 应应用 Gradle 签名配置"

assert_file_contains \
    "$BOOTSTRAP_BUILD" \
    'signingConfigs.getByName("release")' \
    "bootstrap 应配置 release build type"

assert_file_contains \
    "$BOOTSTRAP_PROJECT/.gitignore" \
    "/keystore.properties" \
    "bootstrap 应忽略本地签名配置"

assert_file_contains \
    "$BOOTSTRAP_PROJECT/.gitignore" \
    "/production.p12" \
    "bootstrap 应忽略项目内生成的 keystore"

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "keytool -genkeypair" \
    "bootstrap 应先调用 keytool 生成 keystore"

assert_contains \
    "$calls" \
    "-storepass:env BOOTSTRAP_STOREPASS" \
    "bootstrap 应通过环境变量传递 store 密码"

assert_contains \
    "$calls" \
    "-keypass:env BOOTSTRAP_KEYPASS" \
    "bootstrap 应通过环境变量传递 key 密码"

if [[ "$calls" == *"$BOOTSTRAP_STOREPASS"* ||
      "$calls" == *"$BOOTSTRAP_KEYPASS"* ]]; then
    fail "bootstrap 的 keytool 参数不得泄漏密码值"
fi

keygen_line="$(
    grep -nF \
        "Bootstrap：生成 keystore" \
        <<< "$output" |
        head -n 1 |
        cut -d: -f1
)"

setup_line="$(
    grep -nF \
        "Bootstrap：生成签名配置骨架" \
        <<< "$output" |
        head -n 1 |
        cut -d: -f1
)"

init_line="$(
    grep -nF \
        "Bootstrap：创建本地签名配置" \
        <<< "$output" |
        head -n 1 |
        cut -d: -f1
)"

apply_line="$(
    grep -nF \
        "Bootstrap：应用 Gradle 签名配置" \
        <<< "$output" |
        head -n 1 |
        cut -d: -f1
)"

(( keygen_line < setup_line )) ||
    fail "bootstrap 应先执行 keygen 再执行 setup"

(( setup_line < init_line )) ||
    fail "bootstrap 应先执行 setup 再执行 init"

(( init_line < apply_line )) ||
    fail "bootstrap 应先执行 init 再执行 apply"

printf 'PASS release bootstrap completes signing initialization\n\n'

printf 'TEST release bootstrap stops on first failed step\n'

BOOTSTRAP_STOP_PROJECT="$TEST_ROOT/release-bootstrap-stop"
BOOTSTRAP_STOP_KEYSTORE="$BOOTSTRAP_STOP_PROJECT/existing.p12"

mkdir -p "$BOOTSTRAP_STOP_PROJECT/app"

cp "$BOOTSTRAP_PROJECT/gradlew" \
    "$BOOTSTRAP_STOP_PROJECT/gradlew"

cp "$BOOTSTRAP_PROJECT/settings.gradle.kts" \
    "$BOOTSTRAP_STOP_PROJECT/settings.gradle.kts"

cat > "$BOOTSTRAP_STOP_PROJECT/app/build.gradle.kts" <<'BUILD'
plugins {
    id("com.android.application")
}

android {
    namespace = "com.example.bootstrap.stop"
}
BUILD

printf 'valuable existing keystore\n' \
    > "$BOOTSTRAP_STOP_KEYSTORE"

chmod +x "$BOOTSTRAP_STOP_PROJECT/gradlew"

set +e
output="$(
    cd "$BOOTSTRAP_STOP_PROJECT"

    "$TADK_ROOT/bin/tadk" \
        release \
        bootstrap \
        --keystore "$BOOTSTRAP_STOP_KEYSTORE" \
        --alias production \
        --dname "CN=TADK Bootstrap Stop, O=TADK, C=CA" \
        --storepass-env BOOTSTRAP_STOREPASS \
        --module app \
        2>&1
)"
command_status=$?
set -e

assert_failure \
    "$command_status" \
    "已有 keystore 时 bootstrap 默认应失败"

assert_contains \
    "$output" \
    "keystore 已存在，不会覆盖" \
    "bootstrap 应保留 keygen 的失败原因"

assert_contains \
    "$output" \
    "Bootstrap 在步骤“生成 keystore”停止" \
    "bootstrap 应说明停止步骤"

assert_file_contains \
    "$BOOTSTRAP_STOP_KEYSTORE" \
    "valuable existing keystore" \
    "失败时不得破坏已有 keystore"

[[ ! -e "$BOOTSTRAP_STOP_PROJECT/keystore.properties.example" ]] ||
    fail "keygen 失败后不得继续执行 setup"

[[ ! -e "$BOOTSTRAP_STOP_PROJECT/keystore.properties" ]] ||
    fail "keygen 失败后不得继续执行 init"

if grep -Fq \
    "// TADK Release signing begin" \
    "$BOOTSTRAP_STOP_PROJECT/app/build.gradle.kts"; then
    fail "keygen 失败后不得继续执行 apply"
fi

printf 'PASS release bootstrap stops on first failed step\n\n'

printf 'TEST release bootstrap force refreshes managed outputs\n'

printf 'stale keystore\n' > "$BOOTSTRAP_KEYSTORE"
printf 'stale example\n' \
    > "$BOOTSTRAP_PROJECT/keystore.properties.example"
printf 'stale properties\n' \
    > "$BOOTSTRAP_PROJECT/keystore.properties"

python - "$BOOTSTRAP_BUILD" <<'PY_EDIT'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
text = text.replace(
    "val tadkReleaseKeystoreFile =",
    "// stale bootstrap block\nval tadkReleaseKeystoreFile =",
    1,
)
path.write_text(text)
PY_EDIT

output="$(
    cd "$BOOTSTRAP_PROJECT"

    "$TADK_ROOT/bin/tadk" \
        release \
        bootstrap \
        --keystore "$BOOTSTRAP_KEYSTORE" \
        --alias production \
        --dname "CN=TADK Bootstrap, O=TADK, C=CA" \
        --storepass-env BOOTSTRAP_STOREPASS \
        --keypass-env BOOTSTRAP_KEYPASS \
        --module app \
        --force \
        2>&1
)"

assert_contains \
    "$output" \
    "覆盖已有文件：true" \
    "bootstrap --force 应报告覆盖模式"

assert_file_contains \
    "$BOOTSTRAP_KEYSTORE" \
    "mock keystore" \
    "bootstrap --force 应替换已有 keystore"

assert_file_contains \
    "$BOOTSTRAP_PROJECT/keystore.properties.example" \
    "storeFile=release.jks" \
    "bootstrap --force 应刷新配置模板"

assert_file_contains \
    "$BOOTSTRAP_PROJECT/keystore.properties" \
    "keyAlias=production" \
    "bootstrap --force 应刷新本地配置"

if grep -Fq \
    "stale bootstrap block" \
    "$BOOTSTRAP_BUILD"; then
    fail "bootstrap --force 应刷新 TADK Gradle 配置块"
fi

begin_count="$(
    grep -Fxc \
        "// TADK Release signing begin" \
        "$BOOTSTRAP_BUILD"
)"

end_count="$(
    grep -Fxc \
        "// TADK Release signing end" \
        "$BOOTSTRAP_BUILD"
)"

assert_equals \
    "1" \
    "$begin_count" \
    "bootstrap --force 后只能存在一个开始标记"

assert_equals \
    "1" \
    "$end_count" \
    "bootstrap --force 后只能存在一个结束标记"

printf 'PASS release bootstrap force refreshes managed outputs\n\n'

printf 'TEST release bootstrap rejects separate PKCS12 key password\n'

BOOTSTRAP_MISMATCH_PROJECT="$TEST_ROOT/release-bootstrap-mismatch"
BOOTSTRAP_MISMATCH_KEYSTORE="$BOOTSTRAP_MISMATCH_PROJECT/mismatch.p12"

mkdir -p "$BOOTSTRAP_MISMATCH_PROJECT/app"

cp "$BOOTSTRAP_PROJECT/gradlew" \
    "$BOOTSTRAP_MISMATCH_PROJECT/gradlew"

cp "$BOOTSTRAP_PROJECT/settings.gradle.kts" \
    "$BOOTSTRAP_MISMATCH_PROJECT/settings.gradle.kts"

cat > "$BOOTSTRAP_MISMATCH_PROJECT/app/build.gradle.kts" <<'BUILD'
plugins {
    id("com.android.application")
}

android {
    namespace = "com.example.bootstrap.mismatch"
}
BUILD

chmod +x "$BOOTSTRAP_MISMATCH_PROJECT/gradlew"

export BOOTSTRAP_DIFFERENT_KEYPASS='different-bootstrap-secret'

: > "$MOCK_LOG"

set +e
output="$(
    cd "$BOOTSTRAP_MISMATCH_PROJECT"

    "$TADK_ROOT/bin/tadk" \
        release \
        bootstrap \
        --keystore "$BOOTSTRAP_MISMATCH_KEYSTORE" \
        --alias production \
        --dname "CN=TADK Bootstrap Mismatch, O=TADK, C=CA" \
        --storepass-env BOOTSTRAP_STOREPASS \
        --keypass-env BOOTSTRAP_DIFFERENT_KEYPASS \
        --module app \
        --storetype PKCS12 \
        2>&1
)"
command_status=$?
set -e

unset BOOTSTRAP_DIFFERENT_KEYPASS

assert_equals \
    "64" \
    "$command_status" \
    "PKCS12 密码不一致时 bootstrap 应返回用法错误"

assert_contains \
    "$output" \
    "PKCS12 不支持独立的 key 密码" \
    "bootstrap 应保留 PKCS12 密码兼容性错误"

assert_contains \
    "$output" \
    "Bootstrap 在步骤“生成 keystore”停止" \
    "PKCS12 校验失败时应停止在 keygen"

[[ ! -e "$BOOTSTRAP_MISMATCH_KEYSTORE" ]] ||
    fail "PKCS12 密码不一致时不得生成 keystore"

[[ ! -e "$BOOTSTRAP_MISMATCH_PROJECT/keystore.properties.example" ]] ||
    fail "PKCS12 校验失败后不得执行 setup"

calls="$(cat "$MOCK_LOG")"

if [[ "$calls" == *"keytool"* ]]; then
    fail "PKCS12 密码不一致时 bootstrap 不应调用 keytool"
fi

printf 'PASS release bootstrap rejects separate PKCS12 key password\n\n'

printf 'TEST release bootstrap validates required arguments\n'

set +e
output="$(
    cd "$BOOTSTRAP_PROJECT"

    "$TADK_ROOT/bin/tadk" \
        release \
        bootstrap \
        --alias production \
        --dname "CN=TADK Bootstrap, O=TADK, C=CA" \
        --storepass-env BOOTSTRAP_STOREPASS \
        2>&1
)"
command_status=$?
set -e

assert_equals \
    "64" \
    "$command_status" \
    "bootstrap 缺少 keystore 时应返回用法错误"

assert_contains \
    "$output" \
    "bootstrap 缺少 --keystore" \
    "bootstrap 应说明缺少 keystore"

printf 'PASS release bootstrap validates required arguments\n\n'

printf 'TEST release bootstrap dry-run is read-only\n'

: > "$MOCK_LOG"

output="$(
    cd "$BOOTSTRAP_PROJECT"

    "$TADK_ROOT/bin/tadk" \
        release \
        bootstrap \
        --keystore "$BOOTSTRAP_KEYSTORE" \
        --alias production \
        --dname "CN=TADK Bootstrap, O=TADK, C=CA" \
        --storepass-env BOOTSTRAP_STOREPASS \
        --module app \
        --force \
        --dry-run \
        2>&1
)"

assert_contains \
    "$output" \
    "dry-run" \
    "bootstrap dry-run 应报告只读预检"

calls="$(cat "$MOCK_LOG")"

[[ -z "$calls" ]] ||
    fail "bootstrap dry-run 不应调用 keytool 或写入 mock 日志"

printf 'PASS release bootstrap dry-run is read-only\n\n'

printf 'TEST release bootstrap rolls back managed files after a later failure\n'

BOOTSTRAP_ROLLBACK_PROJECT="$TEST_ROOT/release-bootstrap-rollback"
BOOTSTRAP_ROLLBACK_BUILD="$BOOTSTRAP_ROLLBACK_PROJECT/app/build.gradle.kts"
BOOTSTRAP_ROLLBACK_KEYSTORE="$BOOTSTRAP_ROLLBACK_PROJECT/rollback.p12"

mkdir -p "$BOOTSTRAP_ROLLBACK_PROJECT/app"

cp "$BOOTSTRAP_PROJECT/gradlew" \
    "$BOOTSTRAP_ROLLBACK_PROJECT/gradlew"

cp "$BOOTSTRAP_PROJECT/settings.gradle.kts" \
    "$BOOTSTRAP_ROLLBACK_PROJECT/settings.gradle.kts"

cat > "$BOOTSTRAP_ROLLBACK_BUILD" <<'BUILD'
plugins {
    id("com.android.application")
}

android {
    namespace = "com.example.bootstrap.rollback"
    signingConfigs {
        release { }
    }
}
BUILD

chmod +x "$BOOTSTRAP_ROLLBACK_PROJECT/gradlew"

: > "$MOCK_LOG"

set +e
output="$(
    cd "$BOOTSTRAP_ROLLBACK_PROJECT"

    "$TADK_ROOT/bin/tadk" \
        release \
        bootstrap \
        --keystore "$BOOTSTRAP_ROLLBACK_KEYSTORE" \
        --alias rollback \
        --dname "CN=TADK Bootstrap Rollback, O=TADK, C=CA" \
        --storepass-env BOOTSTRAP_STOREPASS \
        --module app \
        2>&1
)"
command_status=$?
set -e

assert_failure \
    "$command_status" \
    "apply 失败时 bootstrap 应返回失败"

assert_contains \
    "$output" \
    "bootstrap rollback completed" \
    "bootstrap 应报告回滚完成"

[[ ! -e "$BOOTSTRAP_ROLLBACK_KEYSTORE" ]] ||
    fail "bootstrap 回滚后不应保留新生成的 keystore"

[[ ! -e "$BOOTSTRAP_ROLLBACK_PROJECT/keystore.properties.example" ]] ||
    fail "bootstrap 回滚后不应保留 setup 模板"

[[ ! -e "$BOOTSTRAP_ROLLBACK_PROJECT/keystore.properties" ]] ||
    fail "bootstrap 回滚后不应保留本地签名配置"

[[ ! -e "$BOOTSTRAP_ROLLBACK_PROJECT/.gitignore" ]] ||
    fail "bootstrap 回滚后不应保留新建的 .gitignore"

if grep -Fq \
    "// TADK Release signing begin" \
    "$BOOTSTRAP_ROLLBACK_BUILD"; then
    fail "bootstrap 回滚后不应保留 Gradle 签名配置"
fi

printf 'PASS release bootstrap rolls back managed files after a later failure\n\n'

unset BOOTSTRAP_STOREPASS
unset BOOTSTRAP_KEYPASS

printf 'PASS: release command integration\n'
