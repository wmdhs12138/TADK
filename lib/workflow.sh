#!/data/data/com.termux/files/usr/bin/bash

# TADK Workflow Engine.
#
# This module is intentionally business-agnostic. It maps symbolic step names
# to shell functions and executes those steps in order.
#
# Public API:
#   workflow_register STEP FUNCTION
#   workflow_has_step STEP
#   workflow_step STEP
#   workflow_run STEP...

if [[ -n "${TADK_WORKFLOW_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_WORKFLOW_SH_LOADED=1

declare -gA TADK_WORKFLOW_STEPS=()

_workflow_error() {
    printf 'workflow: %s\n' "$1" >&2
}

_workflow_valid_name() {
    local name="${1:-}"
    [[ "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]]
}

workflow_register() {
    if (( $# != 2 )); then
        _workflow_error 'usage: workflow_register STEP FUNCTION'
        return 64
    fi

    local step="$1"
    local function_name="$2"

    if ! _workflow_valid_name "$step"; then
        _workflow_error "invalid step name: $step"
        return 64
    fi

    if ! _workflow_valid_name "$function_name"; then
        _workflow_error "invalid function name: $function_name"
        return 64
    fi

    if workflow_has_step "$step"; then
        _workflow_error "step already registered: $step"
        return 65
    fi

    if ! declare -F "$function_name" >/dev/null 2>&1; then
        _workflow_error "function not found: $function_name"
        return 127
    fi

    TADK_WORKFLOW_STEPS["$step"]="$function_name"
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

    if ! workflow_has_step "$step"; then
        _workflow_error "unknown step: $step"
        return 66
    fi

    local function_name="${TADK_WORKFLOW_STEPS[$step]}"

    if ! declare -F "$function_name" >/dev/null 2>&1; then
        _workflow_error "registered function is unavailable: $function_name"
        return 127
    fi

    "$function_name"
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
