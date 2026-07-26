#!/usr/bin/env bash

# English message catalog.

tadk_register_message 'prefix.error' 'Error: '
tadk_register_message 'app.title' 'TADK — Termux Android DevKit'
tadk_register_message 'app.version' 'Version: %s'
tadk_register_message 'app.usage' 'Usage:'
tadk_register_message 'app.commands' 'Commands:'
tadk_register_message 'app.other' 'Other:'
tadk_register_message 'app.help' 'Show this help'
tadk_register_message 'app.version_command' 'Show the TADK version'
tadk_register_message 'app.no_commands' 'Unable to read the command registry'
tadk_register_message 'error.invalid_command_name' 'Invalid command name: %s'
tadk_register_message 'error.unknown_command' 'Unknown command: %s'
tadk_register_message 'error.command_not_executable' 'Command is not executable: %s'
tadk_register_message 'command.manifest.missing' 'Command registry not found'
tadk_register_message 'command.manifest.invalid_name' 'Invalid command name on registry line %s: %s'
tadk_register_message 'command.manifest.missing_description' 'Missing description on registry line %s'
tadk_register_message 'command.manifest.unknown_description' 'Unknown description key on registry line %s: %s'
tadk_register_message 'command.manifest.missing_target' 'Missing execution target on registry line %s'
tadk_register_message 'command.manifest.target_missing' 'Registry target does not exist: %s'

tadk_register_message 'legacy.unknown_option' 'Unknown option: %s'
tadk_register_message 'legacy.unknown_subcommand' 'Unknown config subcommand: %s'
tadk_register_message 'legacy.unknown_action' 'Unknown release operation: %s'
tadk_register_message 'legacy.internal_error' 'Internal error: %s'
tadk_register_message 'legacy.project_path_missing' 'Project directory does not exist: %s'
tadk_register_message 'legacy.project_path_invalid' 'Directory is not inside a valid Gradle Android project: %s'
tadk_register_message 'legacy.project_current_invalid' 'The current directory is not inside a valid Gradle Android project'
tadk_register_message 'legacy.config_missing' 'Project configuration does not exist: %s'
tadk_register_message 'legacy.config_load_failed' 'Unable to load project configuration, status: %s'
tadk_register_message 'legacy.gradle_module_task_missing' 'Unable to determine the module Gradle build task'
tadk_register_message 'legacy.gradle_task_missing' 'Unable to determine the Gradle build task'
tadk_register_message 'legacy.apk_invalid' 'APK does not exist or is not a valid APK: %s'
tadk_register_message 'legacy.apk_missing' 'APK does not exist: %s'
tadk_register_message 'legacy.apk_not_found_build' 'No %s APK found; run: tadk build'
tadk_register_message 'legacy.app_start_failed' 'Application failed to start: %s'
tadk_register_message 'legacy.app_started' 'Application started'
tadk_register_message 'legacy.app_id_missing_skip' 'Unable to resolve applicationId; launch skipped'
tadk_register_message 'legacy.package_missing_logcat' 'Unable to resolve the application package; cannot enter logcat'
tadk_register_message 'legacy.package_missing' 'Unable to resolve the application package; use: %s'
tadk_register_message 'legacy.app_wait_timeout' 'Timed out waiting for the application process: %s'
tadk_register_message 'legacy.app_waiting' 'Waiting for the application to start: %s'
tadk_register_message 'legacy.app_launching' 'Application is not running; launching: %s'
tadk_register_message 'legacy.app_stopping' 'Stopping application: %s'
tadk_register_message 'legacy.app_stop_failed' 'Unable to stop application: %s'
tadk_register_message 'legacy.build_succeeded' 'Build succeeded in %s'
tadk_register_message 'legacy.apk_label' 'APK: %s'
tadk_register_message 'legacy.size_label' 'Size: %s'
tadk_register_message 'legacy.build_apk_missing' 'Build completed, but no %s APK was found'
tadk_register_message 'legacy.clean_succeeded' 'Clean completed'
tadk_register_message 'legacy.clean_nothing' 'No project cache requires cleaning'
tadk_register_message 'legacy.config_valid' 'Project configuration is valid: %s'
tadk_register_message 'legacy.config_updated' 'Project configuration updated: %s'
tadk_register_message 'legacy.adb_connect_failed' 'ADB connection failed'
tadk_register_message 'legacy.adb_connect_succeeded' 'ADB connection succeeded'
tadk_register_message 'legacy.adb_pair_failed' 'ADB pairing failed'
tadk_register_message 'legacy.adb_pair_succeeded' 'ADB pairing completed'
tadk_register_message 'legacy.adb_disconnect_failed' 'ADB disconnection failed'
tadk_register_message 'legacy.adb_disconnected' 'ADB device disconnected'
tadk_register_message 'legacy.step' 'Step %s'
tadk_register_message 'legacy.reject_empty_path' 'Refusing to delete an empty path'
tadk_register_message 'legacy.reject_root_path' 'Refusing to delete the root directory'
tadk_register_message 'legacy.reject_home_path' 'Refusing to delete the HOME directory'
tadk_register_message 'legacy.reject_outside_path' 'Refusing to delete a path outside the project: %s'
tadk_register_message 'legacy.option_missing' 'Option %s is missing a value'
tadk_register_message 'legacy.option_duplicate' 'Option %s may only be specified once'
tadk_register_message 'legacy.option_conflict' 'Options %s and %s cannot be used together'
tadk_register_message 'legacy.single_value' 'Only one value may be specified: %s'
tadk_register_message 'legacy.extra_argument' 'Unexpected argument: %s'
tadk_register_message 'legacy.unsupported_argument' '%s does not support argument: %s'
tadk_register_message 'legacy.unsupported_format' 'Unsupported log format: %s'
tadk_register_message 'legacy.positive_integer' '%s must be a positive integer'

tadk_register_message 'label.project' 'Project: %s'
tadk_register_message 'label.config' 'Config: %s'
tadk_register_message 'label.version' 'Version: %s'
tadk_register_message 'label.module' 'Module: %s'
tadk_register_message 'label.variant' 'Variant: %s'
tadk_register_message 'label.type' 'Type: %s'
tadk_register_message 'label.task' 'Task: %s'
tadk_register_message 'label.clean' 'Clean: %s'
tadk_register_message 'label.arguments' 'Arguments:'
tadk_register_message 'label.size' 'Size: %s'
tadk_register_message 'label.count' 'Count: %s'
tadk_register_message 'label.mode' 'Mode: %s'
tadk_register_message 'label.execution' 'Execution: %s'
tadk_register_message 'label.global_gradle_cache' 'Global Gradle cache: %s'
tadk_register_message 'label.cache_preserved' 'This directory is not removed by tadk clean.'
tadk_register_message 'label.removed' 'Removed: %s directories'
tadk_register_message 'label.released' 'Released approximately: %s'
tadk_register_message 'label.clean_hint' 'Hint: use tadk clean --deep to clean the project .gradle cache.'
tadk_register_message 'label.global_cache_preserved' 'Global Gradle cache preserved: %s'
tadk_register_message 'label.target_device' 'Target device: %s'
tadk_register_message 'label.logcat' 'Logcat: %s'
tadk_register_message 'label.build_type' 'Build type: %s'
tadk_register_message 'label.build_clean' 'Clean before build: %s'
tadk_register_message 'label.clear_logs' 'Clear old logs: %s'
tadk_register_message 'label.restart_app' 'Restart application: %s'
tadk_register_message 'label.follow_logs' 'Follow logs: %s'
tadk_register_message 'label.log_format' 'Log format: %s'
tadk_register_message 'label.log_snapshot' 'Log snapshot: %s'
tadk_register_message 'label.log_lines' 'Log lines: %s'
tadk_register_message 'label.apk' 'APK: %s'
tadk_register_message 'label.source' 'Source: %s'
tadk_register_message 'label.reinstall' 'Replace installation: %s'
tadk_register_message 'label.downgrade' 'Allow downgrade: %s'
tadk_register_message 'label.grant' 'Grant permissions: %s'
tadk_register_message 'label.adb_arguments' 'ADB arguments:'
tadk_register_message 'label.package' 'Package: %s'
tadk_register_message 'label.restart' 'Restart: %s'
tadk_register_message 'label.pid' 'Process PID: %s'
tadk_register_message 'label.listen' 'Listen: %s'
tadk_register_message 'label.format' 'Format: %s'
tadk_register_message 'label.address' 'Address: %s'
tadk_register_message 'label.serial' 'Serial: %s'
tadk_register_message 'label.state' 'State: %s'
tadk_register_message 'label.details' 'Details: %s'
tadk_register_message 'label.action' 'Action: %s'
tadk_register_message 'label.device' 'Device: %s'
tadk_register_message 'label.android' 'Android: %s'
tadk_register_message 'label.sdk' 'SDK: %s'
tadk_register_message 'label.connection' 'Connection: %s'
tadk_register_message 'label.wireless_address' 'Wireless address: %s'
tadk_register_message 'label.foreground_app' 'Foreground application: %s'
tadk_register_message 'label.total_devices' 'Total devices: %s'
tadk_register_message 'label.available_devices' 'Available devices: %s'
tadk_register_message 'label.archive' 'Archive: %s'
tadk_register_message 'label.local_cache_total' 'Local project cache total'
tadk_register_message 'clean.preview_item' 'Would remove: %s (%s)'
tadk_register_message 'clean.remove_item' 'Remove: %s (%s)'
tadk_register_message 'state.compatibility_mode' 'Config: not found, using compatibility mode'
tadk_register_message 'state.deep_clean' 'Mode: deep clean'
tadk_register_message 'state.standard_clean' 'Mode: standard clean'
tadk_register_message 'state.preview' 'Execution: preview mode'
tadk_register_message 'state.delete' 'Execution: delete'
tadk_register_message 'status.complete' 'Done.'
tadk_register_message 'status.only_build' 'Build-only mode; installation was skipped.'
tadk_register_message 'status.logcat_enter' 'Entering application logs; press Ctrl+C to stop'
tadk_register_message 'status.installing_apk' 'Starting APK installation'
tadk_register_message 'status.install_success' 'APK installed successfully'
tadk_register_message 'status.building' 'Starting APK build'
tadk_register_message 'status.open_installer' 'Opening the system installer'
tadk_register_message 'status.termux_open_missing' 'termux-open was not found'
tadk_register_message 'status.apk_generated' 'APK generated: %s'
tadk_register_message 'status.adb_installing' 'Installing APK through ADB'
tadk_register_message 'status.adb_install_success' 'ADB installation succeeded'
tadk_register_message 'status.release_signing_valid' 'Release signing verification environment is ready'
tadk_register_message 'state.build_type_explicit' 'Build type: %s (specified on the command line)'
tadk_register_message 'state.build_type_configured' 'Build type: determined by project configuration or the default'
tadk_register_message 'state.logcat_crash' 'Mode: crash buffer'
tadk_register_message 'state.logcat_all' 'Mode: all device logs'
tadk_register_message 'status.clear_log_buffer' 'Clear log buffer'
tadk_register_message 'status.log_buffer_cleared' 'Log buffer cleared'
tadk_register_message 'status.stop_logcat' 'Press Ctrl+C to stop following logs.'
tadk_register_message 'value.unknown' 'Unknown'
tadk_register_message 'value.default_device' 'ADB default device'
tadk_register_message 'value.explicit_apk_path' 'Explicit APK path'
tadk_register_message 'value.wireless_debug' 'Wireless debugging'
tadk_register_message 'value.usb_local_adb' 'USB or local ADB'
tadk_register_message 'value.not_applicable' 'Not applicable'
tadk_register_message 'value.not_found' 'Not found'
tadk_register_message 'device.authorize_hint' 'Allow USB/wireless debugging authorization on the device'
tadk_register_message 'device.reconnect_hint' 'Reconnect the device or restart the ADB service'
tadk_register_message 'device.check_hint' 'Check the ADB connection and device authorization status'
tadk_register_message 'device.enable_hint' 'Enable wireless debugging and complete the ADB connection first.'
tadk_register_message 'adb.no_ready_devices' 'No connected and authorized ADB devices were found.'
tadk_register_message 'adb.connect_authorization_hint' 'Connect a device and complete debugging authorization first.'
tadk_register_message 'adb.multiple_devices' 'Multiple ADB devices are available'
tadk_register_message 'adb.device_option_hint' 'Use --device SERIAL to select a target device.'
tadk_register_message 'adb.device_unavailable' 'The selected ADB device is unavailable: %s'
tadk_register_message 'adb.device_auto_unavailable' 'The automatically selected ADB device is unavailable: %s'
tadk_register_message 'adb.device_check_hint' 'Check the device address, connection, and debugging authorization.'
tadk_register_message 'adb.install_hint' 'Run: pkg install android-tools'
tadk_register_message 'connect.address_format' 'Address format must be HOST:PORT, for example 192.168.1.8:37123'
tadk_register_message 'connect.no_devices' 'There are currently no ADB devices'
tadk_register_message 'connect.pair_next' 'Use the connect address shown on the device next:'
tadk_register_message 'connect.command_completed' 'ADB command completed; check the result'
tadk_register_message 'connect.devices_heading' 'Current ADB devices'
tadk_register_message 'connect.address_empty' 'ADB address must not be empty'
tadk_register_message 'connect.address_whitespace' 'ADB address must not contain whitespace: %s'
tadk_register_message 'connect.address_invalid' 'Invalid ADB address: %s'
tadk_register_message 'connect.port_invalid' 'Invalid ADB port: %s'
tadk_register_message 'connect.connecting' 'Connecting to wireless debugging device: %s'
tadk_register_message 'connect.pairing' 'Pairing wireless debugging device: %s'
tadk_register_message 'connect.disconnecting' 'Disconnecting wireless debugging device: %s'
tadk_register_message 'connect.disconnecting_all' 'Disconnecting all TCP/IP ADB devices'

tadk_register_message 'command.doctor.description' 'Inspect the Termux Android development environment'
tadk_register_message 'command.devices.description' 'List ADB devices and Android system information'
tadk_register_message 'command.connect.description' 'Pair, connect, and disconnect Android wireless debugging devices'
tadk_register_message 'command.init.description' 'Initialize TADK configuration for an existing Android project'
tadk_register_message 'command.config.description' 'Show and validate TADK configuration for an Android project'
tadk_register_message 'command.build.description' 'Build the APK for the current Android project'
tadk_register_message 'command.apk.description' 'Find and list APKs generated by the current project'
tadk_register_message 'command.release.description' 'Inspect and verify Android Release signing'
tadk_register_message 'command.install.description' 'Install an existing APK through ADB'
tadk_register_message 'command.self-update.description' 'Check a TADK archive or apply an update'
tadk_register_message 'command.launch.description' 'Launch an installed Android application through ADB'
tadk_register_message 'command.logcat.description' 'View logs from the current Android application'
tadk_register_message 'command.run.description' 'Build and run the current Android project'
tadk_register_message 'command.dev.description' 'Run the build, install, launch, and log development workflow'
tadk_register_message 'command.clean.description' 'Clean build caches from the current project'
tadk_register_message 'command.info.description' 'Show information about the current Android project'

tadk_register_message 'help.newapp' "$(cat <<'HELP'
Usage:
  newapp <PROJECT_NAME> <PACKAGE_NAME>

Examples:
  newapp MyApp com.example.myapp
  newapp BalanceApp com.fu.balanceapp

Rules:
  PROJECT_NAME may contain only letters and numbers and must start with a letter.
  PACKAGE_NAME must use lowercase letters, numbers, underscores, and dots.
HELP
)"
tadk_register_message 'newapp.invalid_project_name' 'Invalid project name: %s'
tadk_register_message 'newapp.invalid_package_name' 'Invalid package name: %s'
tadk_register_message 'newapp.template_missing' 'Template does not exist: %s'
tadk_register_message 'newapp.destination_exists' 'Destination already exists: %s'
tadk_register_message 'newapp.android_home_missing' 'ANDROID_HOME is not set'
tadk_register_message 'newapp.android_api_missing' 'Android API 36 was not found: %s'
tadk_register_message 'newapp.main_activity_missing' 'MainActivity.kt does not exist in the template'
tadk_register_message 'newapp.create_project' 'Creating project: %s'
tadk_register_message 'newapp.application_package' 'Application package: %s'
tadk_register_message 'newapp.target_directory' 'Target directory: %s'
tadk_register_message 'newapp.first_build' 'Running the first build…'
tadk_register_message 'newapp.created' 'Project created successfully'
tadk_register_message 'newapp.directory' 'Directory: %s'
tadk_register_message 'newapp.package' 'Package: %s'
tadk_register_message 'newapp.apk' 'APK: %s'
tadk_register_message 'newapp.enter_project' 'Enter the project:'
tadk_register_message 'newapp.install_apk' 'Install the APK:'
tadk_register_message 'newapp.build_failed' 'Project files were created, but the first build failed.'
tadk_register_message 'newapp.inspect_directory' 'Enter the directory to inspect: %s'
tadk_register_message 'self_update.preflight_heading' 'TADK Self-update Preflight'
tadk_register_message 'self_update.apply_heading' 'TADK Self-update Apply'
tadk_register_message 'self_update.archive' 'Archive: %s'
tadk_register_message 'self_update.read_only' 'Mode: read-only'
tadk_register_message 'self_update.transactional' 'Mode: transactional apply'
tadk_register_message 'self_update.committed' 'Self-update apply transaction committed'
tadk_register_message 'self_update.failed' 'Self-update apply transaction failed; target was rolled back when possible'
tadk_register_message 'doctor.termux_found' 'Termux environment: %s'
tadk_register_message 'doctor.termux_missing' 'Termux environment was not detected'
tadk_register_message 'doctor.bash_found' 'Bash found: %s'
tadk_register_message 'doctor.bash_missing' 'Bash was not found in PATH'
tadk_register_message 'doctor.java_found' 'Java found: %s'
tadk_register_message 'doctor.java_missing' 'Java was not found in PATH'
tadk_register_message 'doctor.wrapper_missing' 'Gradle Wrapper does not exist: %s'
tadk_register_message 'doctor.wrapper_unreadable' 'Gradle Wrapper is not readable: %s'
tadk_register_message 'doctor.wrapper_unexecutable' 'Gradle Wrapper is not executable: %s'
tadk_register_message 'doctor.wrapper_found' 'Gradle Wrapper found: %s'
tadk_register_message 'doctor.sdk_vars_missing' 'Neither ANDROID_HOME nor ANDROID_SDK_ROOT is set'
tadk_register_message 'doctor.sdk_missing' 'Android SDK directory does not exist: %s'
tadk_register_message 'doctor.sdk_found' 'Android SDK found: %s'
tadk_register_message 'doctor.adb_missing' 'ADB was not found in PATH'
tadk_register_message 'doctor.adb_found' 'ADB found: %s'
tadk_register_message 'doctor.adb_ready' 'At least one authorized ADB device is connected'
tadk_register_message 'doctor.adb_not_ready' 'No authorized ADB device is connected'
tadk_register_message 'doctor.manifest_found' 'Android manifest found: %s'
tadk_register_message 'doctor.manifest_missing' 'No AndroidManifest.xml was found'
tadk_register_message 'doctor.apk_output_found' 'APK output directory found: %s'
tadk_register_message 'doctor.apk_output_missing' 'No APK output directory exists yet'
tadk_register_message 'doctor.summary' 'Doctor summary'
tadk_register_message 'doctor.passed' 'Passed: %s'
tadk_register_message 'doctor.warnings' 'Warnings: %s'
tadk_register_message 'doctor.failed' 'Failed: %s'
tadk_register_message 'doctor.heading' 'TADK doctor'
tadk_register_message 'info.section.project' 'Project'
tadk_register_message 'info.section.android' 'Android'
tadk_register_message 'info.section.version' 'Version'
tadk_register_message 'info.section.build_tools' 'Build tools'
tadk_register_message 'info.section.git' 'Git'
tadk_register_message 'info.section.artifacts' 'Artifacts'
tadk_register_message 'info.row.name' 'Name'
tadk_register_message 'info.row.root' 'Root'
tadk_register_message 'info.row.build_file' 'Build file'
tadk_register_message 'info.row.namespace' 'Namespace'
tadk_register_message 'info.row.application_id' 'Application ID'
tadk_register_message 'info.row.compile_sdk' 'Compile SDK'
tadk_register_message 'info.row.min_sdk' 'Min SDK'
tadk_register_message 'info.row.target_sdk' 'Target SDK'
tadk_register_message 'info.row.compose' 'Compose'
tadk_register_message 'info.row.version_name' 'Version name'
tadk_register_message 'info.row.version_code' 'Version code'
tadk_register_message 'info.row.gradle' 'Gradle'
tadk_register_message 'info.row.android_gradle' 'Android Gradle'
tadk_register_message 'info.row.kotlin' 'Kotlin'
tadk_register_message 'info.row.branch' 'Branch'
tadk_register_message 'info.row.commit' 'Commit'
tadk_register_message 'info.row.status' 'Status'
tadk_register_message 'info.row.repository' 'Repository'
tadk_register_message 'info.row.debug_apk' 'Debug APK'
tadk_register_message 'info.row.release_apk' 'Release APK'
tadk_register_message 'info.value.not_built' 'Not built'
tadk_register_message 'info.value.unknown_size' 'Unknown size'
tadk_register_message 'info.value.clean' 'Clean'
tadk_register_message 'info.value.modified' 'Modified (%s files)'
tadk_register_message 'info.value.not_initialized' 'Not initialized'

tadk_register_message 'help.apk' "$(cat <<'HELP'
Usage:
  tadk apk [options]

Description:
  Find APKs already generated by the current Android project.
  This command does not build, install, or launch anything.

Options:
  --debug            Find the Debug APK (default)
  --release          Find the Release APK
  --all              List all matching APKs
  --path-only        Print only APK paths
  --relative         Use paths relative to the project root
  --no-size          Do not show APK file sizes
  -h, --help         Show this help

Examples:
  tadk apk
  tadk apk --release
  tadk apk --all
  tadk apk --all --release
  tadk apk --path-only
  tadk apk --path-only --relative
HELP
)"

tadk_register_message 'help.build' "$(cat <<'HELP'
Usage:
  tadk build [options]

Description:
  Build the APK for the current Android project.

  If .tadk/project.conf exists, its module and variant are used by default.
  The --debug and --release options override the configured variant.

Options:
  --debug            Build a Debug APK
  --release          Build a Release APK
  --clean            Run Gradle clean before building
  --no-cache         Disable the Gradle build cache
  --rerun            Force all Gradle tasks to run again
  --                Pass following arguments directly to Gradle
  -h, --help         Show this help

Precedence:
  --debug / --release
      > variant in project.conf
      > default debug

Examples:
  tadk build
  tadk build --release
  tadk build --clean --no-cache
  tadk build -- --stacktrace
HELP
)"

tadk_register_message 'help.clean' "$(cat <<'HELP'
Usage:
  tadk clean [options]

Options:
  --deep          Also clean the current project's .gradle cache
  --status        Show current project build-cache usage only
  --dry-run       Show what would be removed without deleting anything
  -h, --help      Show this help
HELP
)"

tadk_register_message 'help.config' "$(cat <<'HELP'
Usage:
  tadk config show [PROJECT_ROOT]
  tadk config validate [PROJECT_ROOT]
  tadk config set module MODULE [PROJECT_ROOT]
  tadk config set variant debug|release [PROJECT_ROOT]
  tadk config [options]

Description:
  Show, validate, or update TADK configuration for the current Android project.

  Without PROJECT_ROOT, search upward from the current directory for the project root.

Subcommands:
  show                Show project configuration
  validate            Validate project configuration
  set                 Update module or variant

Options:
  -h, --help          Show this help

Arguments:
  MODULE              Android Gradle module name
  PROJECT_ROOT        Android project root or any directory inside the project

Configuration file:
  .tadk/project.conf

Examples:
  tadk config show
  tadk config validate
  tadk config set module app
  tadk config set module mobile ~/projects/MyApp
  tadk config set variant release
  tadk config set variant debug ~/projects/MyApp/app/src/main
HELP
)"

tadk_register_message 'help.connect' "$(cat <<'HELP'
Usage:
  tadk connect ADDRESS
  tadk connect --pair ADDRESS
  tadk connect --pair ADDRESS CODE
  tadk connect --disconnect ADDRESS
  tadk connect --disconnect-all

Description:
  Manage ADB pairing, connection, and disconnection for Android wireless debugging.

  Android wireless debugging normally shows two separate addresses:

    Pairing address    Used by adb pair
    Connect address    Used by adb connect

  Their ports may differ. After pairing, use the connect address with:

    tadk connect ADDRESS

Operations:
  ADDRESS                   Connect to a wireless debugging device
  --pair ADDRESS [CODE]     Pair a wireless debugging device
  --disconnect ADDRESS      Disconnect the specified wireless device
  --disconnect-all          Disconnect all TCP/IP ADB devices

Other:
  -h, --help                Show this help

Examples:
  tadk connect 192.168.1.8:37123
  tadk connect --pair 192.168.1.8:41237
  tadk connect --pair 192.168.1.8:41237 123456
  tadk connect --disconnect 192.168.1.8:37123
  tadk connect --disconnect-all
HELP
)"

tadk_register_message 'help.dev' "$(cat <<'HELP'
Usage:
  tadk dev [options]

Description:
  Run the complete Android development loop:

    Build
      → Install
      → Clear old logs
      → Launch the application
      → Follow application logs

  dev orchestrates existing atomic commands instead of reimplementing their internals.

Build options:
  --debug             Build and install a Debug APK
  --release           Build and install a Release APK
  --clean             Run Gradle clean before building
  --no-cache          Disable the Gradle build cache
  --rerun             Force all Gradle tasks to run again

Run options:
  --device SERIAL     Set the ADB target for the entire workflow
  --no-clear          Do not clear Logcat before launching
  --no-restart        Do not force-stop the old process
  --no-logcat         Do not read logs after launching

Log options:
  --dump              Print current logs and exit
  --lines NUMBER      Print only the most recent number of lines and exit
  --format FORMAT     Set the Logcat format (default: threadtime)
  --raw-output        Hide the TADK heading during the Logcat stage

Argument forwarding:
  --build-arg ARG     Pass one argument to Gradle
  --install-arg ARG   Pass one argument to adb install
  --logcat-arg ARG    Pass one argument to adb logcat

Other:
  -h, --help          Show this help

Examples:
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
Usage:
  tadk devices [--json]

Description:
  List ADB-visible devices and show their model, Android version, SDK,
  connection method, wireless debugging address, and foreground application.

Status values:
  device        Device is connected and authorized
  unauthorized  Device has not authorized the current ADB client
  offline       Device is offline
  no permissions
                The current environment cannot access the device

Options:
  -h, --help            Show this help
  --json                Print machine-readable JSON

Example:
  tadk devices
HELP
)"

tadk_register_message 'help.doctor' "$(cat <<'HELP'
Usage:
  tadk doctor [--json] [PROJECT_ROOT]

Description:
  Inspect the Termux Android development environment and project configuration.

  Without PROJECT_ROOT, inspect the current working directory.

Arguments:
  PROJECT_ROOT          Android project root (default: current directory)

Options:
  -h, --help            Show this help
  --json                Print machine-readable JSON

Examples:
  tadk doctor
  tadk doctor .
  tadk doctor ~/projects/MyApp
HELP
)"

tadk_register_message 'help.info' "$(cat <<'HELP'
Usage:
  tadk info

Description:
  Show the current Android project's name, package, SDK, version,
  Gradle, Kotlin, AGP, Git status, and APK information.

Run this command from the project root or any subdirectory.
HELP
)"

tadk_register_message 'help.init' "$(cat <<'HELP'
Usage:
  tadk init [options] [PROJECT_ROOT]

Description:
  Create TADK project configuration in an existing Gradle Android project.

  Without PROJECT_ROOT, search upward from the current directory for the project root.

Options:
  --force             Overwrite an existing .tadk/project.conf
  --module MODULE     Set the Android application module, for example feature/chat
  -h, --help          Show this help

Arguments:
  PROJECT_ROOT        Android project root or any directory inside the project

Generated file:
  .tadk/project.conf

Examples:
  tadk init
  tadk init --force
  tadk init --module mobile
  tadk init ~/projects/MyApp
  tadk init --module feature/chat ~/projects/MyApp
  tadk init --force ~/projects/MyApp
HELP
)"

tadk_register_message 'help.install' "$(cat <<'HELP'
Usage:
  tadk install [options] [APK_PATH]

Description:
  Install an existing APK without building or launching the application.

  Without an APK path, use the configured module and variant from
  .tadk/project.conf when available.

Options:
  --debug            Install the newest Debug APK
  --release          Install the newest Release APK
  --apk PATH         Install the specified APK
  --device SERIAL    Set the ADB target device
  --no-reinstall     Do not use -r for replacement installation
  --downgrade        Allow version downgrade (adb install -d)
  --grant            Grant runtime permissions (adb install -g)
  --                Pass following arguments directly to adb install
  -h, --help         Show this help

Precedence:
  Explicit APK path
      > configured module

  --debug / --release
      > variant in project.conf
      > default debug

Examples:
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
Usage:
  tadk launch [options] [PACKAGE_NAME]

Description:
  Launch an Android application already installed on the device.
  This command does not build or install anything.

Options:
  --package NAME     Set the application package name
  --device SERIAL    Set the ADB target device
  --restart          Force-stop the application before launching
  -h, --help         Show this help

Package resolution order:
  1. Package name from the command line
  2. applicationId from the module in project.conf
  3. namespace from the module in project.conf
  4. applicationId or namespace scan when no configuration exists

Examples:
  tadk launch
  tadk launch com.example.app
  tadk launch --package com.example.app
  tadk launch --device 172.19.0.1:39439
  tadk launch --restart
HELP
)"

tadk_register_message 'help.logcat' "$(cat <<'HELP'
Usage:
  tadk logcat [options]

Description:
  Resolve the applicationId for the module in project.conf, find its process
  ID, and show only that application's logs. Without project configuration,
  retain the compatible project-wide scan behavior.

Options:
  --package NAME     Set the application package name
  --device SERIAL    Set the ADB target device
  --all              Show all device logs without application filtering
  --crash            Show the crash buffer and exit automatically
  --clear            Clear the buffer before reading logs
  --clear-only       Clear the buffer without reading logs
  --dump             Print current logs and exit without following
  --lines NUMBER     Print only the most recent number of lines and exit
  --format FORMAT    Set the log format (default: threadtime)
  --launch           Launch the app and wait for its process if it is not running
  --restart          Force-stop and relaunch the app, then wait for its process
  --wait             Wait for the app to be started by the user or another event
  --raw-output       Hide the TADK heading for redirection or AI processing
  --                Pass following arguments directly to adb logcat
  -h, --help         Show this help

Supported formats:
  brief
  process
  tag
  thread
  raw
  time
  threadtime
  long

Examples:
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
Usage:
  tadk release doctor
  tadk release verify [APK]
  tadk release build [build options]
  tadk release keystore KEYSTORE [options]
  tadk release setup [options]
  tadk release init [options]
  tadk release keygen [options]
  tadk release apply [options]
  tadk release bootstrap [options]

Operations:
  doctor              Inspect the Android Release signing environment
  verify [APK]        Verify the APK signature, certificate, and file digest
  build               Build a Release APK and verify its signature
  keystore            Inspect keystore contents and signing certificates
  setup               Generate a secure Release signing configuration skeleton
  init                Create local keystore.properties
  keygen              Create an Android Release keystore
  apply               Apply Gradle Release signing configuration
  bootstrap           Initialize the complete Release signing chain

Build options:
  --clean             Run Gradle clean before building
  --no-cache          Disable the Gradle build cache
  --rerun             Force all Gradle tasks to run again
  --                  Pass following arguments directly to Gradle

keystore options:
  --alias ALIAS       Check only the specified keystore entry
  --storepass-env VAR Read the keystore password from environment variable VAR

setup options:
  --module MODULE     Set the Android application module
  --force             Overwrite existing TADK signing templates

init options:
  --keystore PATH     Set an existing keystore
  --alias ALIAS       Set the signing alias
  --storepass-env VAR Read the keystore password from an environment variable
  --keypass-env VAR   Read the key password from an environment variable
  --validate-only     Validate the keystore password and alias without writing configuration
  --force             Overwrite an existing keystore.properties

keygen options:
  --keystore PATH     Set the keystore to create
  --alias ALIAS       Set the signing alias
  --dname NAME        Set the certificate Distinguished Name
  --storepass-env VAR Read the keystore password from an environment variable
  --keypass-env VAR   Read the key password from an environment variable
  --keyalg ALG        Key algorithm (RSA supported; default: RSA)
  --keysize SIZE      RSA key length (default: 4096)
  --validity DAYS     Certificate validity in days (default: 10000)
  --storetype TYPE    Keystore type: PKCS12 or JKS
  --force             Safely replace an existing keystore
  --verbose           Show detailed keytool output

apply options:
  --module MODULE     Set the Android application module
  --check             Only check whether signing configuration is applied
  --force             Regenerate existing TADK signing blocks

bootstrap options:
  --keystore PATH     Set the keystore to create
  --alias ALIAS       Set the signing alias
  --dname NAME        Set the certificate Distinguished Name
  --storepass-env VAR Read the keystore password from an environment variable
  --keypass-env VAR   Read the key password from an environment variable
  --module MODULE     Set the Android application module
  --keyalg ALG        Key algorithm (RSA supported; default: RSA)
  --keysize SIZE      RSA key length (default: 4096)
  --validity DAYS     Certificate validity in days (default: 10000)
  --storetype TYPE    Keystore type: PKCS12 or JKS
  --force             Overwrite existing bootstrap-managed files
  --verbose           Show detailed keytool output
  --dry-run           Run preflight only and show files that would be written

Description:
  Without an APK, verify searches the current Android project for the newest
  Release APK. With .tadk/project.conf, only the configured module is checked.

  build always builds a Release APK and reuses the project configuration,
  module resolution, and Gradle argument handling from tadk build. Signature
  verification runs automatically after a successful build.

  apply changes only the TADK marker block in the module's Gradle build file.
  It does not read keystore passwords or create or modify a keystore.

Examples:
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
Usage:
  tadk run [options]

Description:
  Build an APK and, depending on the selected mode, open the installer,
  install through ADB, or only build.

  If .tadk/project.conf exists, its module and variant are used.
  The --debug and --release options override the configured variant.

Options:
  --build-only       Build the APK without opening or installing it
  --install          Install the APK with adb install -r
  --open             Open the installer with termux-open (default)
  --device SERIAL    Set the ADB target device
  --debug            Build a Debug APK
  --release          Build a Release APK
  --clean            Run Gradle clean before building
  --logcat           Enter application logs after installing and launching
  --no-cache         Disable the Gradle build cache
  --rerun            Force all Gradle tasks to run again
  --                Pass following arguments directly to Gradle
  -h, --help         Show this help

Precedence:
  --debug / --release
      > variant in project.conf
      > default debug

Examples:
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
Usage: tadk self-update (--check ARCHIVE | --apply ARCHIVE) [options]

Validate or transactionally apply a TADK full or update archive.

Options:
  --check ARCHIVE       Archive to validate
  --apply ARCHIVE       Archive to apply to the current TADK_ROOT
  --sha256 HASH         Expected SHA-256 checksum
  --backup-dir DIR      Empty directory outside TADK_ROOT for the backup
  --json                Print one machine-readable JSON result
  -h, --help            Show this help

Examples:
  tadk self-update --check TADK-0.3.0-alpha.19-update.zip \
    --sha256 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
  tadk self-update --check TADK-0.3.0-alpha.19.zip --json
  tadk self-update --apply TADK-0.3.0-alpha.19-update.zip \
    --sha256 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
HELP
)"
