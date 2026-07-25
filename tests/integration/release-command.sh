#!/data/data/com.termux/files/usr/bin/bash

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
#!/data/data/com.termux/files/usr/bin/bash

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
#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

printf 'keytool' >> "$MOCK_LOG"

for argument in "$@"; do
    printf ' %q' "$argument" >> "$MOCK_LOG"
done

printf '\n' >> "$MOCK_LOG"

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
#!/data/data/com.termux/files/usr/bin/bash

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
#!/data/data/com.termux/files/usr/bin/bash

printf 'TEST_APK_SHA256  %s\n' "$1"
MOCK_SHA256SUM

chmod +x \
    "$MOCK_BIN/keytool" \
    "$MOCK_BIN/apksigner" \
    "$MOCK_BIN/sha256sum"

export MOCK_LOG
export PATH="$MOCK_BIN:$PATH"

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

printf 'PASS: release command integration\n'
