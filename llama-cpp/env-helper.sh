#!/bin/bash
# Shared .env parser — handles single quotes, double quotes, and no quotes.
# Source this file to get the `get_env` function.
#
# Usage:
#   source env-helper.sh
#   VALUE="$(get_env SOME_VAR)"

# Resolve ENV_FILE if not already set (default: ../.env relative to this file)
ENV_FILE="${ENV_FILE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.env}"

[[ -f "$ENV_FILE" ]] || { echo "ERROR: $ENV_FILE not found" >&2; exit 1; }

get_env() {
	grep -m1 "^${1}=" "$ENV_FILE" \
		| sed "s/^${1}=//" | tr -d '\r' \
		| sed "s/^[[:space:]]*//;s/[[:space:]]*$//" \
		| sed "s/^'//;s/'$//" \
		| sed 's/^"//;s/",$//;s/"$//' \
		| sed 's/,$//'
}
