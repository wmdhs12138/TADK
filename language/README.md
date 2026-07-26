# TADK language resources

TADK keeps command-line presentation text in this directory.

- `en.sh` — English messages
- `zh-CN.sh` — Simplified Chinese messages

Set `TADK_LANG` to choose the interface language:

    TADK_LANG=en tadk --help
    TADK_LANG=zh-CN tadk --help

When `TADK_LANG` is not set, TADK uses `LC_ALL`, `LC_MESSAGES`, or `LANG`.
If no locale is available, it preserves the default Simplified Chinese
interface.

Command implementations should use message keys through `tadk_text`,
`tadk_label`, or `tadk_print_help` instead of embedding user-facing text.
