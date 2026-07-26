# Termux Android DevKit

[English](README.md) | [简体中文](README.zh-CN.md)

TADK 是一套以 Termux 为核心的 Android 开发工具包，可直接在 ARM64
Android 设备上创建、构建和维护现代 Android 应用。

## 当前功能

- 创建 Kotlin 和 Jetpack Compose 项目
- Material 3 项目模板
- 支持 Android SDK 36
- 支持 Gradle Wrapper
- 兼容 Termux 原生 AAPT2
- 自动初始化 Git 仓库
- APK 查找、安装和应用启动命令
- 按应用包名过滤的 logcat 支持
- 组合式 `tadk dev` 开发工作流
- 基于工作流的 `tadk run` 编排
- ADB 设备检查、无线配对和目标设备选择
- Release APK 验证和签名配置工作流
- 通过 `.tadk/project.conf` 初始化已有项目
- 在 build/install/run/dev 工作流中支持已配置的模块和变体
- 通过 `tadk doctor` 进行环境诊断

## 项目状态

当前开发版本：`0.3.0-alpha.19`

Alpha.18 增加了持久化 Android 项目配置。TADK 现在可以初始化已有项目，
并在构建、安装、运行和开发工作流中统一应用已配置的模块和变体。

开发分支还包含 ADB 设备工作流，以及用于检查、配置和验证 Release APK
的签名工具链。当前的强化工作增加了显式/嵌套模块选择和可恢复的 Release
初始化配置。

这是一个 alpha 版本，面向 ARM64 Android 设备上的 Termux 开发和部署场景。

## 语言支持

TADK 支持英文和简体中文命令行输出。可以为单条命令设置 `TADK_LANG`，
也可以为当前 Shell 导出该变量：

    TADK_LANG=en tadk --help
    TADK_LANG=zh-CN tadk --help

语言资源位于 [`language/`](language/) 目录。未设置 `TADK_LANG` 时，TADK
会根据 Shell locale 选择语言；没有可用 locale 时默认使用简体中文。

## 安装和更新 TADK

TADK 当前使用经过验证的手动压缩包工作流。新安装请使用完整压缩包，已有
安装请使用更新压缩包。校验和验证、暂存、备份及安装完整性步骤请参阅
[`APPLY.md`](APPLY.md)。

更新已有安装前，先运行只读预检：

    tadk self-update --check TADK-<version>-update.zip --sha256 <sha256>

`tadk install` 命令用于在 Android 设备上安装 APK，不会更新 TADK 工具包本身。

## 使用方法

创建项目：

    tadk newapp MyApp com.example.myapp

## 初始化已有项目

在已有 Android Gradle 项目中运行：

    tadk init
    tadk init --module feature/chat

TADK 会创建：

    .tadk/project.conf

示例：

    version=1
    module=app
    variant=debug

嵌套 Android 模块使用相对于项目根目录的路径，例如 `feature/chat`。构建时，
TADK 会将其转换为对应的 Gradle 项目路径。

已配置的模块和变体会应用于：

    tadk build
    tadk install
    tadk run
    tadk dev

命令行中的 `--debug` 和 `--release` 选项优先级高于已配置的变体。

## 环境诊断

检查 Java、Android SDK、ARM64 构建工具和 TADK 是否已正确配置：

    tadk doctor

在脚本和 CI 中请求稳定的 JSON 结果：

    tadk doctor --json

## 设备和 Release 签名

检查已连接 Android 设备及其当前状态：

    tadk devices

在脚本和 CI 中请求稳定的 JSON 设备清单：

    tadk devices --json

配对、连接或断开 Android 无线调试设备：

    tadk connect --pair HOST:PAIR_PORT
    tadk connect HOST:CONNECT_PORT

检查 Release 环境并验证 Release APK：

    tadk release doctor
    tadk release doctor --json
    tadk release verify
    tadk release build

完整的签名配置工作流可通过 `tadk release bootstrap` 使用。密码通过环境变量
提供，不会写入命令参数。使用 `tadk release bootstrap --dry-run` 可先查看目标；
实际初始化会使用临时事务快照，如果后续步骤失败，则回滚由工具管理的文件。

## 构建并运行应用

在 Android 项目根目录或其任意子目录中运行：

    tadk run

常用选项：

    tadk run --build-only
    tadk run --clean
    tadk run --install
    tadk run --release --build-only

存在 `.tadk/project.conf` 时，TADK 会使用其中配置的模块和变体。没有配置时，
TADK 保留现有的 Debug 和全项目兼容行为。

`--debug` 和 `--release` 选项会覆盖已配置的变体。默认情况下，`tadk run` 会
使用 `termux-open` 打开 Android 软件包安装器。

在内部，`tadk run` 使用工作流引擎执行以下阶段：

    build
    resolve-apk
    report
    build-only / open-installer / adb-install
    adb-launch
    complete

## 开发工作流

使用一条命令完成构建、安装、启动和日志检查：

    tadk dev

清理旧日志和跟踪 logcat 等条件阶段由工作流引擎步骤实现。

## 清理项目构建文件

移除当前 Android 项目的构建输出：

    tadk clean

查看项目缓存占用但不删除任何内容：

    tadk clean --status

预览清理操作：

    tadk clean --dry-run

移除构建输出和项目本地 Gradle 缓存：

    tadk clean --deep

TADK 不会删除位于 `~/.gradle/caches` 下的全局 Gradle 依赖缓存。

## 内部架构

TADK 命令共享可复用的 Shell 库：

    lib/common.sh    通用输出、命令和大小辅助函数
    lib/project.sh   Android Gradle 项目发现
    lib/module.sh    Android 模块路径验证和 Gradle 路径映射
    lib/apk.sh       APK 构件发现
    lib/build.sh     Gradle 构建执行
    lib/adb.sh       ADB 操作
    lib/android.sh   Android 项目元数据
    lib/workflow.sh  可复用的工作流编排

命令应复用这些库，避免重复实现项目发现、构建、APK、ADB 或输出逻辑。
