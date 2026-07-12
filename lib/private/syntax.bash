#!/usr/bin/env bash
#
# syntax.bash - regex definitions for argivo

set -Eeuo pipefail

# Prevent loading this module more than once
[[ -n "${_ARGIVO_SYNTAX_LOADED:-}" ]] && return 0
_ARGIVO_SYNTAX_LOADED=true

# General
_ARGIVO_REGEX_EMPTY="^[[:space:]]*$"
_ARGIVO_REGEX_OPEN_BRACE="^[[:space:]]*\{([[:space:]]*#.*)?$"
_ARGIVO_REGEX_ANNOTATION="^[[:space:]]*#[[:space:]]*@([[:alpha:]_][[:alnum:]_-]*)[[:space:]]*(.*)?$"
_ARGIVO_REGEX_SHEBANG="^#!/usr/bin/env argivo$"

# Function declarations
_ARGIVO_REGEX_FUNCTION_1="^[[:space:]]*function[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*(\(\))?([[:space:]]*\{)?[[:space:]]*$"
_ARGIVO_REGEX_FUNCTION_2="^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\)([[:space:]]*\{)?[[:space:]]*$"
_ARGIVO_REGEX_MAIN="^[[:space:]]*(function[[:space:]]+)?main[[:space:]]*(\(\))?"

# Directives
_ARGIVO_REGEX_DIRECTIVE="^[[:space:]]*#[[:space:]]*@argivo[[:space:]]+([a-zA-Z_][a-zA-Z0-9_-]*)=(.*)$"
_ARGIVO_REGEX_DIRECTIVE_VALUE="^([a-zA-Z_][a-zA-Z0-9_-]*)=([^[:space:]]+)$"

# Annotations
_ARGIVO_REGEX_HIDDEN="^[[:space:]]*#[[:space:]]*@hidden[[:space:]]*$"
_ARGIVO_REGEX_DESC="^[[:space:]]*#[[:space:]]*@desc[[:space:]]+(.*)$"
_ARGIVO_REGEX_PARAM="^[[:space:]]*#[[:space:]]*@param[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)([[:space:]]+.*)?$"
_ARGIVO_REGEX_EXAMPLE="^[[:space:]]*#[[:space:]]*@example[[:space:]]+(.*)$"
_ARGIVO_REGEX_ALIAS="^[[:space:]]*#[[:space:]]*@alias[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*$"
_ARGIVO_REGEX_EXCL="^[[:space:]]*#[[:space:]]*@excl[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*([[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*)*)[[:space:]]*$"
_ARGIVO_REGEX_REQ="^[[:space:]]*#[[:space:]]*@req[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*([[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*)*)[[:space:]]*$"

# Parameter metadata
_ARGIVO_REGEX_PARAM_SYNTAX="^[a-zA-Z_][a-zA-Z0-9_]*([[:space:]]+type=[a-zA-Z_][a-zA-Z0-9_]*([[:space:]]+default=[^[:space:]]+)?)?([[:space:]]+optional)?([[:space:]]+.+)?$"
_ARGIVO_REGEX_PARAM_TYPE="[[:space:]]type=([^[:space:]]+)"
_ARGIVO_REGEX_PARAM_DEFAULT="[[:space:]]default=([^[:space:]]+)"

# Generic values
_ARGIVO_REGEX_IDENTIFIER="^[a-zA-Z_][a-zA-Z0-9_]*$"
_ARGIVO_REGEX_IDENTIFIER_LIST="^[a-zA-Z_][a-zA-Z0-9_]*([[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*)*$"
_ARGIVO_REGEX_BOOLEAN="^(true|false)$"
_ARGIVO_REGEX_VERSION="^[0-9]+\.[0-9]+\.[0-9]+$"