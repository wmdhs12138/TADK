#!/data/data/com.termux/files/usr/bin/bash

# TADK Workflow Engine.
#
# This module is intentionally business-agnostic. It maps symbolic step names
# to shell functions and executes those steps in order.
#
# Public API:
#   workflow_register STEP FUNCTION
#   workflow_before STEP FUNCTION
#   workflow_after STEP FUNCTION
#   workflow_has_step STEP
#   workflow_step STEP
#   workflow_run STEP...
#
# Exit codes:
#   64  invalid arguments or names
#   65  duplicate step registration
#   66  unknown step
#   127 missing or unavailable function

if [[ -n "${TADK_WORKFLOW_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_WORKFLOW_SH_LOADED=1

declare -gA TADK_WORKFLOW_STEPS=()
declare -gA TADK_WORKFLOW_BEFORE=()
declare -gA TADK_WORKFLOW_AFTER=()

_workflow_error() {
    printf 'workflow: %s\n' "$1" >&2
}

_workflow_valid_name() {
    local name="${1:-}"
    [[ "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]]
}

_workflow_require_valid_step_name() {
    if (( $# != 1 )); then
        _workflow_error \
            'internal error: _workflow_require_valid_step_name requires one argument'
        return 64
    fi

    local step="$1"

    if ! _workflow_valid_name "$step"; then
        _workflow_error "invalid step name: $step"
        return 64
    fi
}

_workflow_require_function() {
    if (( $# != 1 )); then
        _workflow_error \
            'internal error: _workflow_require_function requires one argument'
        return 64
    fi

    local function_name="$1"

    if ! _workflow_valid_name "$function_name"; then
        _workflow_error "invalid function name: $function_name"
        return 64
    fi

    if ! declare -F "$function_name" >/dev/null 2>&1; then
        _workflow_error "function not found: $function_name"
        return 127
    fi
}

_workflow_require_registered_step() {
    if (( $# != 1 )); then
        _workflow_error \
            'internal error: _workflow_require_registered_step requires one argument'
        return 64
    fi

    local step="$1"

    if ! workflow_has_step "$step"; then
        _workflow_error "unknown step: $step"
        return 66
    fi
}

_workflow_append_hook() {
    if (( $# != 3 )); then
        _workflow_error \
            'internal error: _workflow_append_hook requires TYPE STEP FUNCTION'
        return 64
    fi

    local hook_type="$1"
    local step="$2"
    local function_name="$3"

    case "$hook_type" in
        before)
            if [[ -n "${TADK_WORKFLOW_BEFORE[$step]:-}" ]]; then
                TADK_WORKFLOW_BEFORE["$step"]+=" $function_name"
            else
                TADK_WORKFLOW_BEFORE["$step"]="$function_name"
            fi
            ;;

        after)
            if [[ -n "${TADK_WORKFLOW_AFTER[$step]:-}" ]]; then
                TADK_WORKFLOW_AFTER["$step"]+=" $function_name"
            else
                TADK_WORKFLOW_AFTER["$step"]="$function_name"
            fi
            ;;

        *)
            _workflow_error "internal error: unknown hook type: $hook_type"
            return 64
            ;;
    esac
}

_workflow_run_hook_list() {
    if (( $# != 1 )); then
        _workflow_error \
            'internal error: _workflow_run_hook_list requires one argument'
        return 64
    fi

    local hook_list="$1"
    local hook
    local exit_code

    [[ -n "$hook_list" ]] || return 0

    for hook in $hook_list; do
        if ! declare -F "$hook" >/dev/null 2>&1; then
            _workflow_error "registered function is unavailable: $hook"
            return 127
        fi

        "$hook"
        exit_code=$?

        if (( exit_code != 0 )); then
            return "$exit_code"
        fi
    done
}

workflow_register() {
    if (( $# != 2 )); then
        _workflow_error 'usage: workflow_register STEP FUNCTION'
        return 64
    fi

    local step="$1"
    local function_name="$2"

    _workflow_require_valid_step_name "$step" || return $?
    _workflow_require_function "$function_name" || return $?

    if workflow_has_step "$step"; then
        _workflow_error "step already registered: $step"
        return 65
    fi

    TADK_WORKFLOW_STEPS["$step"]="$function_name"
    TADK_WORKFLOW_BEFORE["$step"]=''
    TADK_WORKFLOW_AFTER["$step"]=''
}

workflow_before() {
    if (( $# != 2 )); then
        _workflow_error 'usage: workflow_before STEP FUNCTION'
        return 64
    fi

    local step="$1"
    local function_name="$2"

    _workflow_require_valid_step_name "$step" || return $?
    _workflow_require_registered_step "$step" || return $?
    _workflow_require_function "$function_name" || return $?

    _workflow_append_hook before "$step" "$function_name"
}

workflow_after() {
    if (( $# != 2 )); then
        _workflow_error 'usage: workflow_after STEP FUNCTION'
        return 64
    fi

    local step="$1"
    local function_name="$2"

    _workflow_require_valid_step_name "$step" || return $?
    _workflow_require_registered_step "$step" || return $?
    _workflow_require_function "$function_name" || return $?

    _workflow_append_hook after "$step" "$function_name"
}

workflow_has_step() {
    if (( $# != 1 )); then
        _workflow_error 'usage: workflow_has_step STEP'
        return 64
    fi

    local step="$1"

    [[ -n "${TADK_WORKFLOW_STEPS[$step]+registered}" ]]
}

workflow_step() {
    if (( $# != 1 )); then
        _workflow_error 'usage: workflow_step STEP'
        return 64
    fi

    local step="$1"
    local function_name
    local exit_code

    _workflow_require_registered_step "$step" || return $?

    function_name="${TADK_WORKFLOW_STEPS[$step]}"

    if ! declare -F "$function_name" >/dev/null 2>&1; then
        _workflow_error "registered function is unavailable: $function_name"
        return 127
    fi

    _workflow_run_hook_list "${TADK_WORKFLOW_BEFORE[$step]:-}"
    exit_code=$?

    if (( exit_code != 0 )); then
        return "$exit_code"
    fi

    "$function_name"
    exit_code=$?

    if (( exit_code != 0 )); then
        return "$exit_code"
    fi

    _workflow_run_hook_list "${TADK_WORKFLOW_AFTER[$step]:-}"
}

workflow_run() {
    if (( $# == 0 )); then
        _workflow_error 'workflow_run requires at least one step'
        return 64
    fi

    local step
    local exit_code

    for step in "$@"; do
        workflow_step "$step"
        exit_code=$?

        if (( exit_code != 0 )); then
            return "$exit_code"
        fi
    done
}