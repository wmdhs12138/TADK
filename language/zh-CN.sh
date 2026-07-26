#!/usr/bin/env bash

# Simplified Chinese message catalog.

tadk_register_message 'prefix.error' '错误：'
tadk_register_message 'app.title' 'TADK — Termux Android DevKit'
tadk_register_message 'app.version' '版本：%s'
tadk_register_message 'app.usage' '用法：'
tadk_register_message 'app.commands' '命令：'
tadk_register_message 'app.other' '其他：'
tadk_register_message 'app.help' '显示帮助'
tadk_register_message 'app.version_command' '显示 TADK 版本'
tadk_register_message 'app.no_commands' '无法读取命令注册表'
tadk_register_message 'error.invalid_command_name' '无效命令名：%s'
tadk_register_message 'error.unknown_command' '未知命令：%s'
tadk_register_message 'error.command_not_executable' '命令不可执行：%s'
tadk_register_message 'command.manifest.missing' '未找到命令注册表'
tadk_register_message 'command.manifest.invalid_name' '注册表第 %s 行命令名无效：%s'
tadk_register_message 'command.manifest.missing_description' '注册表第 %s 行缺少描述'
tadk_register_message 'command.manifest.unknown_description' '注册表第 %s 行描述键不存在：%s'
tadk_register_message 'command.manifest.missing_target' '注册表第 %s 行缺少执行目标'
tadk_register_message 'command.manifest.target_missing' '注册表目标不存在：%s'

tadk_register_message 'legacy.unknown_option' '未知参数：%s'
tadk_register_message 'legacy.unknown_subcommand' '未知 config 子命令：%s'
tadk_register_message 'legacy.unknown_action' '未知 release 操作：%s'
tadk_register_message 'legacy.internal_error' '内部错误：%s'
tadk_register_message 'legacy.project_path_missing' '项目目录不存在：%s'
tadk_register_message 'legacy.project_path_invalid' '指定目录不在有效的 Gradle Android 项目中：%s'
tadk_register_message 'legacy.project_current_invalid' '当前目录不在有效的 Gradle Android 项目中'
tadk_register_message 'legacy.config_missing' '项目配置不存在：%s'
tadk_register_message 'legacy.config_load_failed' '无法加载项目配置，状态码：%s'
tadk_register_message 'legacy.gradle_module_task_missing' '无法确定模块 Gradle 构建任务'
tadk_register_message 'legacy.gradle_task_missing' '无法确定 Gradle 构建任务'
tadk_register_message 'legacy.apk_invalid' 'APK 不存在或不是有效的 APK 文件：%s'
tadk_register_message 'legacy.apk_missing' 'APK 不存在：%s'
tadk_register_message 'legacy.apk_not_found_build' '未找到 %s APK，请先执行：tadk build'
tadk_register_message 'legacy.app_start_failed' '应用启动失败：%s'
tadk_register_message 'legacy.app_started' '应用已启动'
tadk_register_message 'legacy.app_id_missing_skip' '无法识别 applicationId，已跳过启动'
tadk_register_message 'legacy.package_missing_logcat' '无法识别应用包名，不能进入日志'
tadk_register_message 'legacy.package_missing' '无法识别应用包名，请使用：%s'
tadk_register_message 'legacy.app_wait_timeout' '等待应用进程超时：%s'
tadk_register_message 'legacy.app_waiting' '等待应用启动：%s'
tadk_register_message 'legacy.app_launching' '应用未运行，正在启动：%s'
tadk_register_message 'legacy.app_stopping' '停止应用：%s'
tadk_register_message 'legacy.app_stop_failed' '无法停止应用：%s'
tadk_register_message 'legacy.build_succeeded' '构建成功，用时 %s'
tadk_register_message 'legacy.apk_label' 'APK：%s'
tadk_register_message 'legacy.size_label' '大小：%s'
tadk_register_message 'legacy.build_apk_missing' '构建完成，但未找到 %s APK'
tadk_register_message 'legacy.clean_succeeded' '清理完成'
tadk_register_message 'legacy.clean_nothing' '没有发现需要清理的项目缓存'
tadk_register_message 'legacy.config_valid' '项目配置有效：%s'
tadk_register_message 'legacy.config_updated' '项目配置已更新：%s'
tadk_register_message 'legacy.adb_connect_failed' 'ADB 连接失败'
tadk_register_message 'legacy.adb_connect_succeeded' 'ADB 连接成功'
tadk_register_message 'legacy.adb_pair_failed' 'ADB 配对失败'
tadk_register_message 'legacy.adb_pair_succeeded' 'ADB 配对完成'
tadk_register_message 'legacy.adb_disconnect_failed' 'ADB 断开失败'
tadk_register_message 'legacy.adb_disconnected' 'ADB 设备已断开'
tadk_register_message 'legacy.step' '步骤 %s'
tadk_register_message 'legacy.reject_empty_path' '拒绝删除空路径'
tadk_register_message 'legacy.reject_root_path' '拒绝删除根目录'
tadk_register_message 'legacy.reject_home_path' '拒绝删除 HOME 目录'
tadk_register_message 'legacy.reject_outside_path' '拒绝删除项目目录之外的路径：%s'
tadk_register_message 'legacy.option_missing' '%s 缺少参数'
tadk_register_message 'legacy.option_duplicate' '%s 不能重复指定'
tadk_register_message 'legacy.option_conflict' '%s 不能与 %s 同时使用'
tadk_register_message 'legacy.single_value' '只能指定一个值：%s'
tadk_register_message 'legacy.extra_argument' '多余参数：%s'
tadk_register_message 'legacy.unsupported_argument' '%s 不支持参数：%s'
tadk_register_message 'legacy.unsupported_format' '不支持的日志格式：%s'
tadk_register_message 'legacy.positive_integer' '%s 必须是大于 0 的整数'

tadk_register_message 'label.project' '项目：%s'
tadk_register_message 'label.config' '配置：%s'
tadk_register_message 'label.version' '版本：%s'
tadk_register_message 'label.module' '模块：%s'
tadk_register_message 'label.variant' '变体：%s'
tadk_register_message 'label.type' '类型：%s'
tadk_register_message 'label.task' '任务：%s'
tadk_register_message 'label.clean' '清理：%s'
tadk_register_message 'label.arguments' '参数：'
tadk_register_message 'label.size' '大小：%s'
tadk_register_message 'label.count' '数量：%s'
tadk_register_message 'label.mode' '模式：%s'
tadk_register_message 'label.execution' '执行：%s'
tadk_register_message 'label.global_gradle_cache' '全局 Gradle 缓存：%s'
tadk_register_message 'label.cache_preserved' '该目录不会被 tadk clean 删除。'
tadk_register_message 'label.removed' '已删除：%s 个目录'
tadk_register_message 'label.released' '释放约：%s'
tadk_register_message 'label.clean_hint' '提示：使用 tadk clean --deep 可清理项目 .gradle 缓存。'
tadk_register_message 'label.global_cache_preserved' '全局 Gradle 缓存保留：%s'
tadk_register_message 'label.target_device' '目标设备：%s'
tadk_register_message 'label.logcat' '日志：%s'
tadk_register_message 'label.build_type' '构建类型：%s'
tadk_register_message 'label.build_clean' '构建前清理：%s'
tadk_register_message 'label.clear_logs' '清空旧日志：%s'
tadk_register_message 'label.restart_app' '重新启动应用：%s'
tadk_register_message 'label.follow_logs' '监听日志：%s'
tadk_register_message 'label.log_format' '日志格式：%s'
tadk_register_message 'label.log_snapshot' '日志快照：%s'
tadk_register_message 'label.log_lines' '日志行数：%s'
tadk_register_message 'label.apk' 'APK：%s'
tadk_register_message 'label.source' '来源：%s'
tadk_register_message 'label.reinstall' '覆盖安装：%s'
tadk_register_message 'label.downgrade' '允许降级：%s'
tadk_register_message 'label.grant' '自动授权：%s'
tadk_register_message 'label.adb_arguments' 'ADB 参数：'
tadk_register_message 'label.package' '应用包名：%s'
tadk_register_message 'label.restart' '重新启动：%s'
tadk_register_message 'label.pid' '进程 PID：%s'
tadk_register_message 'label.listen' '监听：%s'
tadk_register_message 'label.format' '格式：%s'
tadk_register_message 'label.address' '地址：%s'
tadk_register_message 'label.serial' '序列号：%s'
tadk_register_message 'label.state' '状态：%s'
tadk_register_message 'label.details' '详情：%s'
tadk_register_message 'label.action' '处理：%s'
tadk_register_message 'label.device' '设备：%s'
tadk_register_message 'label.android' 'Android：%s'
tadk_register_message 'label.sdk' 'SDK：%s'
tadk_register_message 'label.connection' '连接：%s'
tadk_register_message 'label.wireless_address' '无线地址：%s'
tadk_register_message 'label.foreground_app' '前台应用：%s'
tadk_register_message 'label.total_devices' '设备总数：%s'
tadk_register_message 'label.available_devices' '可用设备：%s'
tadk_register_message 'label.archive' '归档：%s'
tadk_register_message 'label.local_cache_total' '项目本地缓存总计'
tadk_register_message 'clean.preview_item' '将删除：%s（%s）'
tadk_register_message 'clean.remove_item' '删除：%s（%s）'
tadk_register_message 'state.compatibility_mode' '配置：未找到，使用兼容模式'
tadk_register_message 'state.deep_clean' '模式：深度清理'
tadk_register_message 'state.standard_clean' '模式：标准清理'
tadk_register_message 'state.preview' '执行：预览模式'
tadk_register_message 'state.delete' '执行：实际删除'
tadk_register_message 'status.complete' '完成。'
tadk_register_message 'status.only_build' '仅构建模式，未执行安装。'
tadk_register_message 'status.logcat_enter' '进入应用日志，按 Ctrl+C 停止'
tadk_register_message 'status.installing_apk' '开始安装 APK'
tadk_register_message 'status.install_success' 'APK 安装成功'
tadk_register_message 'status.building' '开始构建 APK'
tadk_register_message 'status.open_installer' '打开系统安装界面'
tadk_register_message 'status.termux_open_missing' '未找到 termux-open'
tadk_register_message 'status.apk_generated' 'APK 已生成：%s'
tadk_register_message 'status.adb_installing' '通过 ADB 安装 APK'
tadk_register_message 'status.adb_install_success' 'ADB 安装成功'
tadk_register_message 'status.release_signing_valid' 'Release 签名验证环境可用'
tadk_register_message 'state.build_type_explicit' '构建类型：%s（命令行指定）'
tadk_register_message 'state.build_type_configured' '构建类型：由项目配置或默认值决定'
tadk_register_message 'state.logcat_crash' '模式：crash 缓冲区'
tadk_register_message 'state.logcat_all' '模式：设备全部日志'
tadk_register_message 'status.clear_log_buffer' '清空日志缓冲区'
tadk_register_message 'status.log_buffer_cleared' '日志缓冲区已清空'
tadk_register_message 'status.stop_logcat' '按 Ctrl+C 停止监听。'
tadk_register_message 'value.unknown' '未知'
tadk_register_message 'value.default_device' 'ADB 默认设备'
tadk_register_message 'value.explicit_apk_path' '显式 APK 路径'
tadk_register_message 'value.wireless_debug' '无线调试'
tadk_register_message 'value.usb_local_adb' 'USB 或本地 ADB'
tadk_register_message 'value.not_applicable' '不适用'
tadk_register_message 'value.not_found' '未知'
tadk_register_message 'device.authorize_hint' '请在设备上允许 USB/无线调试授权'
tadk_register_message 'device.reconnect_hint' '请重连设备或重启 ADB 服务'
tadk_register_message 'device.check_hint' '请检查 ADB 连接和设备授权状态'
tadk_register_message 'device.enable_hint' '请先启用无线调试并完成 ADB 连接。'
tadk_register_message 'adb.no_ready_devices' '未发现已连接并授权的 ADB 设备。'
tadk_register_message 'adb.connect_authorization_hint' '请先连接设备并完成调试授权。'
tadk_register_message 'adb.multiple_devices' '检测到多个可用 ADB 设备'
tadk_register_message 'adb.device_option_hint' '请使用 --device SERIAL 指定目标设备。'
tadk_register_message 'adb.device_unavailable' '指定的 ADB 设备不可用：%s'
tadk_register_message 'adb.device_auto_unavailable' '自动选择的 ADB 设备不可用：%s'
tadk_register_message 'adb.device_check_hint' '请检查设备地址、连接状态和调试授权。'
tadk_register_message 'adb.install_hint' '请执行：pkg install android-tools'
tadk_register_message 'connect.address_format' '地址格式应为 HOST:PORT，例如 192.168.1.8:37123'
tadk_register_message 'connect.no_devices' '当前没有 ADB 设备'
tadk_register_message 'connect.pair_next' '请使用设备显示的连接地址继续执行：'
tadk_register_message 'connect.command_completed' 'ADB 命令已完成，请检查返回结果'
tadk_register_message 'connect.devices_heading' '当前 ADB 设备'
tadk_register_message 'connect.address_empty' 'ADB 地址不能为空'
tadk_register_message 'connect.address_whitespace' 'ADB 地址不能包含空白字符：%s'
tadk_register_message 'connect.address_invalid' '无效的 ADB 地址：%s'
tadk_register_message 'connect.port_invalid' '无效的 ADB 端口：%s'
tadk_register_message 'connect.connecting' '连接无线调试设备：%s'
tadk_register_message 'connect.pairing' '配对无线调试设备：%s'
tadk_register_message 'connect.disconnecting' '断开无线调试设备：%s'
tadk_register_message 'connect.disconnecting_all' '断开所有 TCP/IP ADB 设备'

tadk_register_message 'command.doctor.description' '检查 Termux Android 开发环境'
tadk_register_message 'command.devices.description' '查看 ADB 设备和 Android 系统信息'
tadk_register_message 'command.connect.description' '配对、连接和断开 Android 无线调试设备'
tadk_register_message 'command.init.description' '初始化现有 Android 项目的 TADK 配置'
tadk_register_message 'command.config.description' '查看和验证 Android 项目的 TADK 配置'
tadk_register_message 'command.build.description' '构建当前 Android 项目的 APK'
tadk_register_message 'command.apk.description' '查找和列出当前项目生成的 APK'
tadk_register_message 'command.release.description' '检查和验证 Android Release 签名'
tadk_register_message 'command.install.description' '通过 ADB 安装已有 APK'
tadk_register_message 'command.self-update.description' '检查 TADK 归档或应用更新'
tadk_register_message 'command.launch.description' '通过 ADB 启动已安装的 Android 应用'
tadk_register_message 'command.logcat.description' '查看当前 Android 应用的运行日志'
tadk_register_message 'command.run.description' '构建并运行当前 Android 项目'
tadk_register_message 'command.dev.description' '执行构建、安装、启动和日志监听开发流程'
tadk_register_message 'command.clean.description' '清理当前项目的构建缓存'
tadk_register_message 'command.info.description' '显示当前 Android 项目信息'

tadk_register_message 'help.newapp' "$(cat <<'HELP'
用法：
  newapp <项目名> <包名>

示例：
  newapp MyApp com.example.myapp
  newapp BalanceApp com.fu.balanceapp

规则：
  项目名只能包含英文字母和数字，并且必须以字母开头。
  包名必须使用小写字母、数字、下划线和点号。
HELP
)"
tadk_register_message 'newapp.invalid_project_name' '项目名无效：%s'
tadk_register_message 'newapp.invalid_package_name' '包名无效：%s'
tadk_register_message 'newapp.template_missing' '模板不存在：%s'
tadk_register_message 'newapp.destination_exists' '目标目录已经存在：%s'
tadk_register_message 'newapp.android_home_missing' 'ANDROID_HOME 尚未设置'
tadk_register_message 'newapp.android_api_missing' '未找到 Android API 36：%s'
tadk_register_message 'newapp.main_activity_missing' '模板中的 MainActivity.kt 不存在'
tadk_register_message 'newapp.create_project' '创建项目：%s'
tadk_register_message 'newapp.application_package' '应用包名：%s'
tadk_register_message 'newapp.target_directory' '目标目录：%s'
tadk_register_message 'newapp.first_build' '正在执行首次构建……'
tadk_register_message 'newapp.created' '项目创建成功'
tadk_register_message 'newapp.directory' '目录：%s'
tadk_register_message 'newapp.package' '包名：%s'
tadk_register_message 'newapp.apk' 'APK：%s'
tadk_register_message 'newapp.enter_project' '进入项目：'
tadk_register_message 'newapp.install_apk' '安装 APK：'
tadk_register_message 'newapp.build_failed' '项目文件已经创建，但首次构建失败。'
tadk_register_message 'newapp.inspect_directory' '请进入目录检查：%s'
tadk_register_message 'self_update.preflight_heading' 'TADK 更新预检'
tadk_register_message 'self_update.apply_heading' 'TADK 更新应用'
tadk_register_message 'self_update.archive' '归档：%s'
tadk_register_message 'self_update.read_only' '模式：只读'
tadk_register_message 'self_update.transactional' '模式：事务应用'
tadk_register_message 'self_update.committed' '更新应用事务已提交'
tadk_register_message 'self_update.failed' '更新应用事务失败；已尽可能回滚目标目录'
tadk_register_message 'doctor.termux_found' 'Termux 环境：%s'
tadk_register_message 'doctor.termux_missing' '未检测到 Termux 环境'
tadk_register_message 'doctor.bash_found' '已找到 Bash：%s'
tadk_register_message 'doctor.bash_missing' 'PATH 中未找到 Bash'
tadk_register_message 'doctor.java_found' '已找到 Java：%s'
tadk_register_message 'doctor.java_missing' 'PATH 中未找到 Java'
tadk_register_message 'doctor.wrapper_missing' 'Gradle Wrapper 不存在：%s'
tadk_register_message 'doctor.wrapper_unreadable' 'Gradle Wrapper 不可读：%s'
tadk_register_message 'doctor.wrapper_unexecutable' 'Gradle Wrapper 不可执行：%s'
tadk_register_message 'doctor.wrapper_found' '已找到 Gradle Wrapper：%s'
tadk_register_message 'doctor.sdk_vars_missing' '尚未设置 ANDROID_HOME 或 ANDROID_SDK_ROOT'
tadk_register_message 'doctor.sdk_missing' 'Android SDK 目录不存在：%s'
tadk_register_message 'doctor.sdk_found' '已找到 Android SDK：%s'
tadk_register_message 'doctor.adb_missing' 'PATH 中未找到 ADB'
tadk_register_message 'doctor.adb_found' '已找到 ADB：%s'
tadk_register_message 'doctor.adb_ready' '至少有一个已连接并授权的 ADB 设备'
tadk_register_message 'doctor.adb_not_ready' '没有已连接并授权的 ADB 设备'
tadk_register_message 'doctor.manifest_found' '已找到 Android manifest：%s'
tadk_register_message 'doctor.manifest_missing' '未找到 AndroidManifest.xml'
tadk_register_message 'doctor.apk_output_found' '已找到 APK 输出目录：%s'
tadk_register_message 'doctor.apk_output_missing' 'APK 输出目录尚不存在'
tadk_register_message 'doctor.summary' 'Doctor 摘要'
tadk_register_message 'doctor.passed' '通过：%s'
tadk_register_message 'doctor.warnings' '警告：%s'
tadk_register_message 'doctor.failed' '失败：%s'
tadk_register_message 'doctor.heading' 'TADK doctor'
tadk_register_message 'info.section.project' '项目'
tadk_register_message 'info.section.android' 'Android'
tadk_register_message 'info.section.version' '版本'
tadk_register_message 'info.section.build_tools' '构建工具'
tadk_register_message 'info.section.git' 'Git'
tadk_register_message 'info.section.artifacts' '构件'
tadk_register_message 'info.row.name' '名称'
tadk_register_message 'info.row.root' '根目录'
tadk_register_message 'info.row.build_file' '构建文件'
tadk_register_message 'info.row.namespace' 'Namespace'
tadk_register_message 'info.row.application_id' 'Application ID'
tadk_register_message 'info.row.compile_sdk' 'Compile SDK'
tadk_register_message 'info.row.min_sdk' 'Min SDK'
tadk_register_message 'info.row.target_sdk' 'Target SDK'
tadk_register_message 'info.row.compose' 'Compose'
tadk_register_message 'info.row.version_name' '版本名称'
tadk_register_message 'info.row.version_code' '版本号'
tadk_register_message 'info.row.gradle' 'Gradle'
tadk_register_message 'info.row.android_gradle' 'Android Gradle'
tadk_register_message 'info.row.kotlin' 'Kotlin'
tadk_register_message 'info.row.branch' '分支'
tadk_register_message 'info.row.commit' '提交'
tadk_register_message 'info.row.status' '状态'
tadk_register_message 'info.row.repository' '仓库'
tadk_register_message 'info.row.debug_apk' 'Debug APK'
tadk_register_message 'info.row.release_apk' 'Release APK'
tadk_register_message 'info.value.not_built' '尚未构建'
tadk_register_message 'info.value.unknown_size' '大小未知'
tadk_register_message 'info.value.clean' '干净'
tadk_register_message 'info.value.modified' '已修改（%s 个文件）'
tadk_register_message 'info.value.not_initialized' '未初始化'

tadk_register_message 'help.apk' "$(cat <<'HELP'
用法：
  tadk apk [选项]

说明：
  查找当前 Android 项目已经生成的 APK。
  不执行构建、安装或启动。

选项：
  --debug            查找 Debug APK（默认）
  --release          查找 Release APK
  --all              列出所有匹配的 APK
  --path-only        只输出 APK 路径
  --relative         使用相对于项目根目录的路径
  --no-size          不显示 APK 文件大小
  -h, --help         显示帮助

示例：
  tadk apk
  tadk apk --release
  tadk apk --all
  tadk apk --all --release
  tadk apk --path-only
  tadk apk --path-only --relative
HELP
)"

tadk_register_message 'help.build' "$(cat <<'HELP'
用法：
  tadk build [选项]

说明：
  构建当前 Android 项目的 APK。

  如果项目存在 .tadk/project.conf，将默认使用其中的 module 和
  variant。命令行中的 --debug 或 --release 会覆盖配置的 variant。

选项：
  --debug            构建 Debug APK
  --release          构建 Release APK
  --clean            构建前先执行 Gradle clean
  --no-cache         禁用 Gradle 构建缓存
  --rerun            强制重新执行所有 Gradle 任务
  --                  将后续参数直接传递给 Gradle
  -h, --help         显示帮助

优先级：
  --debug / --release
      > project.conf 中的 variant
      > 默认 debug

示例：
  tadk build
  tadk build --release
  tadk build --clean --no-cache
  tadk build -- --stacktrace
HELP
)"

tadk_register_message 'help.clean' "$(cat <<'HELP'
用法：
  tadk clean [选项]

选项：
  --deep          同时清理当前项目的 .gradle 缓存
  --status        只显示当前项目构建缓存占用
  --dry-run       显示将删除的内容，不实际删除
  -h, --help      显示帮助
HELP
)"

tadk_register_message 'help.config' "$(cat <<'HELP'
用法：
  tadk config show [PROJECT_ROOT]
  tadk config validate [PROJECT_ROOT]
  tadk config set module MODULE [PROJECT_ROOT]
  tadk config set variant debug|release [PROJECT_ROOT]
  tadk config [选项]

说明：
  查看、验证或修改当前 Android 项目的 TADK 配置。

  未提供 PROJECT_ROOT 时，从当前目录向上查找项目根目录。

子命令：
  show                显示项目配置
  validate            验证项目配置
  set                 修改 module 或 variant

选项：
  -h, --help          显示帮助

参数：
  MODULE              Android Gradle 模块名称
  PROJECT_ROOT        Android 项目根目录或项目内的任意目录

配置文件：
  .tadk/project.conf

示例：
  tadk config show
  tadk config validate
  tadk config set module app
  tadk config set module mobile ~/projects/MyApp
  tadk config set variant release
  tadk config set variant debug ~/projects/MyApp/app/src/main
HELP
)"

tadk_register_message 'help.connect' "$(cat <<'HELP'
用法：
  tadk connect ADDRESS
  tadk connect --pair ADDRESS
  tadk connect --pair ADDRESS CODE
  tadk connect --disconnect ADDRESS
  tadk connect --disconnect-all

说明：
  管理 Android 无线调试的 ADB 配对、连接和断开。

  Android 无线调试通常会分别显示两个地址：

    配对地址    用于 adb pair
    连接地址    用于 adb connect

  两者端口可能不同。完成配对后，请再使用连接地址执行：

    tadk connect ADDRESS

操作：
  ADDRESS                   连接无线调试设备
  --pair ADDRESS [CODE]     配对无线调试设备
  --disconnect ADDRESS      断开指定无线调试设备
  --disconnect-all          断开所有 TCP/IP ADB 设备

其他：
  -h, --help                显示帮助

示例：
  tadk connect 192.168.1.8:37123
  tadk connect --pair 192.168.1.8:41237
  tadk connect --pair 192.168.1.8:41237 123456
  tadk connect --disconnect 192.168.1.8:37123
  tadk connect --disconnect-all
HELP
)"

tadk_register_message 'help.dev' "$(cat <<'HELP'
用法：
  tadk dev [选项]

说明：
  执行完整的 Android 日常开发循环：

    构建
      → 安装
      → 清空旧日志
      → 启动应用
      → 监听应用日志

  dev 只负责编排现有原子命令，不重复实现底层逻辑。

构建选项：
  --debug             构建并安装 Debug APK
  --release           构建并安装 Release APK
  --clean             构建前执行 Gradle clean
  --no-cache          禁用 Gradle 构建缓存
  --rerun             强制重新执行 Gradle 任务

运行选项：
  --device SERIAL     指定整条开发流程的 ADB 目标设备
  --no-clear          启动前不清空 Logcat
  --no-restart        不强制停止旧进程
  --no-logcat         启动应用后不读取日志

日志选项：
  --dump              输出当前日志后退出
  --lines NUMBER      只输出最近指定行数后退出
  --format FORMAT     设置 Logcat 格式，默认 threadtime
  --raw-output        Logcat 阶段不显示 TADK 标题

参数透传：
  --build-arg ARG     向 Gradle 传递一个参数
  --install-arg ARG   向 adb install 传递一个参数
  --logcat-arg ARG    向 adb logcat 传递一个参数

其他：
  -h, --help          显示帮助

示例：
  tadk dev
  tadk dev --clean
  tadk dev --device 172.19.0.1:39439
  tadk dev --no-logcat
  tadk dev --lines 200
  tadk dev --dump --format brief
  tadk dev --build-arg=--stacktrace
  tadk dev --logcat-arg='*:W'
HELP
)"

tadk_register_message 'help.devices' "$(cat <<'HELP'
用法：
  tadk devices [--json]

说明：
  列出当前 ADB 可见设备，并显示设备型号、Android 版本、SDK、
  连接方式、无线调试地址和当前前台应用。

状态说明：
  device        设备已连接并授权
  unauthorized  设备尚未授权当前 ADB 客户端
  offline       设备离线
  no permissions
                当前环境没有访问设备的权限

选项：
  -h, --help            显示帮助
  --json                输出机器可读的 JSON 结果

示例：
  tadk devices
HELP
)"

tadk_register_message 'help.doctor' "$(cat <<'HELP'
用法：
  tadk doctor [--json] [PROJECT_ROOT]

说明：
  检查 Termux Android 开发环境和 Android 项目配置。

  未提供 PROJECT_ROOT 时，检查当前工作目录。

参数：
  PROJECT_ROOT          Android 项目根目录，默认为当前目录

选项：
  -h, --help            显示帮助
  --json                输出机器可读的 JSON 结果

示例：
  tadk doctor
  tadk doctor .
  tadk doctor ~/projects/MyApp
HELP
)"

tadk_register_message 'help.info' "$(cat <<'HELP'
用法：
  tadk info

说明：
  显示当前 Android 项目的名称、包名、SDK、版本、
  Gradle、Kotlin、AGP、Git 状态和 APK 信息。

可以从项目根目录或任意子目录执行。
HELP
)"

tadk_register_message 'help.init' "$(cat <<'HELP'
用法：
  tadk init [选项] [PROJECT_ROOT]

说明：
  在已有 Gradle Android 项目中创建 TADK 项目配置。

  未提供 PROJECT_ROOT 时，从当前目录向上查找项目根目录。

选项：
  --force             覆盖已有的 .tadk/project.conf
  --module MODULE     指定 Android application 模块，例如 feature/chat
  -h, --help          显示帮助

参数：
  PROJECT_ROOT        Android 项目根目录或项目内的任意目录

生成文件：
  .tadk/project.conf

示例：
  tadk init
  tadk init --force
  tadk init --module mobile
  tadk init ~/projects/MyApp
  tadk init --module feature/chat ~/projects/MyApp
  tadk init --force ~/projects/MyApp
HELP
)"

tadk_register_message 'help.install' "$(cat <<'HELP'
用法：
  tadk install [选项] [APK路径]

说明：
  安装已有 APK，不执行构建，也不自动启动应用。

  未指定 APK 路径时，如果项目存在 .tadk/project.conf，将从配置的
  module 中查找 APK，并默认使用配置的 variant。

选项：
  --debug            安装最新 Debug APK
  --release          安装最新 Release APK
  --apk PATH         安装指定 APK
  --device SERIAL    指定 ADB 目标设备
  --no-reinstall     不使用 -r 覆盖安装
  --downgrade        允许版本降级，对应 adb install -d
  --grant            自动授予运行时权限，对应 adb install -g
  --                  将后续参数直接传递给 adb install
  -h, --help         显示帮助

优先级：
  指定 APK 路径
      > 配置模块

  --debug / --release
      > project.conf 中的 variant
      > 默认 debug

示例：
  tadk install
  tadk install --release
  tadk install ./app/build/outputs/apk/debug/app-debug.apk
  tadk install --apk ./my-app.apk
  tadk install --device 172.19.0.1:39439
  tadk install --downgrade --grant
  tadk install -- --user 0
HELP
)"

tadk_register_message 'help.launch' "$(cat <<'HELP'
用法：
  tadk launch [选项] [应用包名]

说明：
  启动设备上已经安装的 Android 应用。
  不执行构建，也不执行安装。

选项：
  --package NAME     指定应用包名
  --device SERIAL    指定 ADB 目标设备
  --restart          启动前先强制停止应用
  -h, --help         显示帮助

包名解析顺序：
  1. 命令行指定的包名
  2. project.conf 指定模块的 applicationId
  3. project.conf 指定模块的 namespace
  4. 无配置时扫描当前项目的 applicationId 或 namespace

示例：
  tadk launch
  tadk launch com.example.app
  tadk launch --package com.example.app
  tadk launch --device 172.19.0.1:39439
  tadk launch --restart
HELP
)"

tadk_register_message 'help.logcat' "$(cat <<'HELP'
用法：
  tadk logcat [选项]

说明：
  默认识别 project.conf 所指定模块的 applicationId，
  获取应用进程 PID，并只显示该应用的日志。
  未配置项目时继续使用兼容的全项目扫描。

选项：
  --package NAME     指定应用包名
  --device SERIAL    指定 ADB 目标设备
  --all              显示设备全部日志，不按应用过滤
  --crash            显示 crash 缓冲区，并自动退出
  --clear            读取日志前先清空缓冲区
  --clear-only       只清空日志缓冲区，不读取日志
  --dump             输出当前日志后退出，不持续监听
  --lines NUMBER     只输出最近指定行数，并退出
  --format FORMAT    设置日志格式，默认 threadtime
  --launch           应用未运行时自动启动并等待进程
  --restart          强制停止后重新启动应用并等待进程
  --wait             等待应用由用户或外部事件启动
  --raw-output       不输出 TADK 标题，便于重定向或交给 AI
  --                 后续参数直接传递给 adb logcat
  -h, --help         显示帮助

支持的格式：
  brief
  process
  tag
  thread
  raw
  time
  threadtime
  long

示例：
  tadk logcat
  tadk logcat --clear
  tadk logcat --dump
  tadk logcat --lines 100
  tadk logcat --package com.example.app
  tadk logcat --device 172.19.0.1:39439
  tadk logcat --launch
  tadk logcat --restart --clear
  tadk logcat --wait
  tadk logcat --all
  tadk logcat --crash
  tadk logcat --raw-output --lines 200 > app.log
  tadk logcat -- --regex 'Exception|FATAL'
HELP
)"

tadk_register_message 'help.release' "$(cat <<'HELP'
用法：
  tadk release doctor
  tadk release verify [APK]
  tadk release build [构建选项]
  tadk release keystore KEYSTORE [选项]
  tadk release setup [选项]
  tadk release init [选项]
  tadk release keygen [选项]
  tadk release apply [选项]
  tadk release bootstrap [选项]

操作：
  doctor              检查 Android Release 签名验证环境
  verify [APK]        验证 APK 签名、证书和文件摘要
  build               构建 Release APK 并验证签名
  keystore            检查 keystore 内容和签名证书
  setup               生成安全的 Release 签名配置骨架
  init                创建本地 keystore.properties
  keygen              创建 Android Release keystore
  apply               应用 Gradle Release 签名配置
  bootstrap           初始化完整 Release 签名链路

构建选项：
  --clean             构建前执行 Gradle clean
  --no-cache          禁用 Gradle 构建缓存
  --rerun             强制重新执行 Gradle 任务
  --                  将后续参数直接传递给 Gradle

keystore 选项：
  --alias ALIAS       只检查指定的 keystore 条目
  --storepass-env VAR 从环境变量 VAR 读取 keystore 密码

setup 选项：
  --module MODULE     指定 Android 应用模块
  --force             覆盖已有的 TADK 签名模板

init 选项：
  --keystore PATH     指定已有 keystore
  --alias ALIAS       指定签名 alias
  --storepass-env VAR 从环境变量读取 keystore 密码
  --keypass-env VAR   从环境变量读取 key 密码
  --validate-only     只校验 keystore 密码和 alias，不写入配置
  --force             覆盖已有 keystore.properties

keygen 选项：
  --keystore PATH     指定要创建的 keystore
  --alias ALIAS       指定签名 alias
  --dname NAME        指定证书 Distinguished Name
  --storepass-env VAR 从环境变量读取 keystore 密码
  --keypass-env VAR   从环境变量读取 key 密码
  --keyalg ALG        密钥算法，当前支持 RSA，默认 RSA
  --keysize SIZE      RSA 密钥长度，默认 4096
  --validity DAYS     证书有效期天数，默认 10000
  --storetype TYPE    keystore 类型：PKCS12 或 JKS
  --force             安全替换已有 keystore
  --verbose           显示 keytool 详细输出

apply 选项：
  --module MODULE     指定 Android 应用模块
  --check             只检查签名配置是否已应用
  --force             重新生成已有 TADK 签名配置块

bootstrap 选项：
  --keystore PATH     指定要创建的 keystore
  --alias ALIAS       指定签名 alias
  --dname NAME        指定证书 Distinguished Name
  --storepass-env VAR 从环境变量读取 keystore 密码
  --keypass-env VAR   从环境变量读取 key 密码
  --module MODULE     指定 Android 应用模块
  --keyalg ALG        密钥算法，当前支持 RSA，默认 RSA
  --keysize SIZE      RSA 密钥长度，默认 4096
  --validity DAYS     证书有效期天数，默认 10000
  --storetype TYPE    keystore 类型：PKCS12 或 JKS
  --force             覆盖 bootstrap 管理的已有文件
  --verbose           显示 keytool 详细输出
  --dry-run           只执行预检并显示将要写入的文件

说明：
  verify 未指定 APK 时，将在当前 Android 项目中查找最新的
  Release APK。如果存在 .tadk/project.conf，则只检查配置的 module。

  build 始终构建 Release APK，并复用 tadk build 的项目配置、
  模块解析和 Gradle 参数处理。构建成功后自动执行签名验证。

  apply 只修改模块 Gradle 构建文件中的 TADK 标记块，不读取
  keystore 密码，也不会创建或修改 keystore。

示例：
  tadk release doctor
  tadk release doctor --json
  tadk release verify
  tadk release verify app/build/outputs/apk/release/app-release.apk
  tadk release build
  tadk release build --clean
  tadk release build -- --stacktrace
  tadk release keystore release.jks
  tadk release keystore release.jks --alias production
  TADK_STOREPASS=secret tadk release keystore release.jks \
    --storepass-env TADK_STOREPASS
  tadk release setup
  tadk release setup --module app
  tadk release init --keystore release.jks --alias release \
    --storepass-env TADK_STOREPASS
  tadk release keygen --keystore release.jks --alias release \
    --dname "CN=My App, O=Personal, C=CA" \
    --storepass-env TADK_STOREPASS
  tadk release apply
  tadk release apply --module app
  tadk release apply --check
  tadk release bootstrap --keystore release.jks --alias release \
    --dname "CN=My App, O=Personal, C=CA" \
    --storepass-env TADK_STOREPASS
HELP
)"

tadk_register_message 'help.run' "$(cat <<'HELP'
用法：
  tadk run [选项]

说明：
  构建 APK，并根据所选模式打开安装界面、通过 ADB 安装，或仅构建。

  如果项目存在 .tadk/project.conf，将使用其中的 module 和 variant。
  命令行中的 --debug 或 --release 会覆盖配置的 variant。

选项：
  --build-only       只构建 APK，不打开或安装
  --install          使用 adb install -r 安装 APK
  --open             使用 termux-open 打开安装界面（默认）
  --device SERIAL    指定 ADB 目标设备
  --debug            构建 Debug APK
  --release          构建 Release APK
  --clean            构建前先执行 Gradle clean
  --logcat           安装并启动后进入应用日志
  --no-cache         禁用 Gradle 构建缓存
  --rerun            强制重新执行所有 Gradle 任务
  --                  将后续参数直接传递给 Gradle
  -h, --help         显示帮助

优先级：
  --debug / --release
      > project.conf 中的 variant
      > 默认 debug

示例：
  tadk run
  tadk run --build-only
  tadk run --install
  tadk run --install --device 172.19.0.1:39439
  tadk run --install --logcat
  tadk run --release --build-only
  tadk run --clean -- --stacktrace
HELP
)"

tadk_register_message 'help.self-update' "$(cat <<'HELP'
用法：tadk self-update (--check ARCHIVE | --apply ARCHIVE) [选项]

验证或以事务方式应用 TADK 完整归档或更新归档。

选项：
  --check ARCHIVE       要验证的归档
  --apply ARCHIVE       要应用到当前 TADK_ROOT 的归档
  --sha256 HASH         期望的 SHA-256 校验和
  --backup-dir DIR      TADK_ROOT 外部用于备份的空目录
  --json                输出一条机器可读的 JSON 结果
  -h, --help            显示帮助

示例：
  tadk self-update --check TADK-0.3.0-alpha.19-update.zip \
    --sha256 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
  tadk self-update --check TADK-0.3.0-alpha.19.zip --json
  tadk self-update --apply TADK-0.3.0-alpha.19-update.zip \
    --sha256 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
HELP
)"
