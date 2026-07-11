#!/bin/bash
# Generate chatLanguageModels JSON from a router INI file.
# Usage: ./generate-json.sh <ini-file> [output-dir]
#
# Reads LOCAL_URL from project root .env (../.env).
# Outputs <ini-file>.json in <output-dir> (defaults to same dir as INI).

set -euo pipefail

INI_FILE="${1:?Usage: $0 <router.ini> [output-dir]}"
INI_FILE="$(realpath "$INI_FILE")"
OUT_DIR="${2:-$(dirname "$INI_FILE")}"
OUT_FILE="${OUT_DIR}/$(basename "${INI_FILE%.ini}.json")"
PROJECT_ROOT="$(cd "$(dirname "$INI_FILE")/.." && pwd)"

# ── Load env vars from .env (parse without source to avoid
#      ${input:...} VS Code variable expansion errors) ───────────
if [[ -f "$PROJECT_ROOT/.env" ]]; then
	ENV_FILE="$PROJECT_ROOT/.env"
elif [[ -f "$(dirname "$INI_FILE")/.env" ]]; then
	ENV_FILE="$(dirname "$INI_FILE")/.env"
else
	echo "ERROR: No .env found near $INI_FILE" >&2
	exit 1
fi

get_env() {
	grep -m1 "^${1}=" "$ENV_FILE" | sed "s/^${1}=//" | tr -d '\r' | sed "s/^[[:space:]]*//;s/[[:space:]]*$//" | sed 's/^"//;s/",$//;s/"$//' | sed 's/,$//'
}

LOCAL_URL="$(get_env LOCAL_URL)"
LOCAL_SERVER_NAME="$(get_env LOCAL_SERVER_NAME)"
LOCAL_API_KEY="$(get_env LOCAL_API_KEY)"

: "${LOCAL_URL:?LOCAL_URL not set in .env}"
: "${LOCAL_SERVER_NAME:?LOCAL_SERVER_NAME not set in .env}"
: "${LOCAL_API_KEY:?LOCAL_API_KEY not set in .env}"

# Strip trailing comma if present (e.g. "LLaMA.cpp Local",)
LOCAL_SERVER_NAME="${LOCAL_SERVER_NAME%,}"

# ── Parse INI & emit JSON via awk ──────────────────────────────────
INI_BASENAME="$(basename "${INI_FILE%.ini}")"
awk -v url="$LOCAL_URL" -v server_name="$LOCAL_SERVER_NAME $INI_BASENAME" -v api_key="$LOCAL_API_KEY" '
BEGIN {
	n = 0
}

# Skip comments and blank lines
/^[[:space:]]*;/ { next }
/^[[:space:]]*$/ { next }

# Section header — skip [*] (global defaults)
/^\[.*\]$/ {
	sec = $0
	gsub(/[\[\]]/, "", sec)
	gsub(/^[[:space:]]+|[[:space:]]+$/, "", sec)
	if (sec == "*") next
	sections[n] = sec
	ctx[sec] = ""
	has_mmproj[sec] = 0
	n++
	next
}

# Key = value
/=/ {
	idx = index($0, "=")
	key = substr($0, 1, idx - 1)
	val = substr($0, idx + 1)
	gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
	gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
	# strip inline comments
	sub(/;.*$/, "", val)
	gsub(/[[:space:]]+$/, "", val)

	if (key == "ctx-size") ctx[sec] = val + 0
	if (key == "mmproj")   has_mmproj[sec] = 1
}

END {
	# ── Build JSON ──
	printf "{\n"
	printf "\t\"name\": \"%s\",\n", server_name
	printf "\t\"vendor\": \"customendpoint\",\n"
	printf "\t\"apiKey\": \"%s\",\n", api_key
	printf "\t\"models\": [\n"

	for (i = 0; i < n; i++) {
		s = sections[i]
		vision = has_mmproj[s] ? "true" : "false"

		max_ctx  = ctx[s] + 0
		max_in   = int(max_ctx * 3 / 4)
		max_out  = int(max_ctx * 1 / 4)

		printf "\t\t{\n"
		printf "\t\t\t\"id\": \"%s\",\n", s
		printf "\t\t\t\"name\": \"%s\",\n", s
		printf "\t\t\t\"url\": \"%s\",\n", url
		printf "\t\t\t\"toolCalling\": true,\n"
		printf "\t\t\t\"vision\": %s,\n", vision
		printf "\t\t\t\"streaming\": true,\n"
		printf "\t\t\t\"apiType\": \"chat-completions\",\n"
		printf "\t\t\t\"editTools\": [\n"
		printf "\t\t\t\t\"apply-patch\",\n"
		printf "\t\t\t\t\"code-rewrite\",\n"
		printf "\t\t\t\t\"find-replace\",\n"
		printf "\t\t\t\t\"multi-find-replace\"\n"
		printf "\t\t\t],\n"
		printf "\t\t\t\"thinking\": true,\n"
		printf "\t\t\t\"supportsReasoningEffort\": [\n"
		printf "\t\t\t\t\"low\",\n"
		printf "\t\t\t\t\"medium\",\n"
		printf "\t\t\t\t\"high\"\n"
		printf "\t\t\t],\n"
		printf "\t\t\t\"reasoningEffortFormat\": \"chat-completions\",\n"
		printf "\t\t\t\"zeroDataRetentionEnabled\": false,\n"
		printf "\t\t\t\"maxInputTokens\": %d,\n", max_in
		printf "\t\t\t\"maxOutputTokens\": %d\n", max_out
		if (i < n - 1)
			printf "\t\t},\n"
		else
			printf "\t\t}\n"
	}

	printf "\t],\n"
	printf "\t\"settings\": {\n"

	for (i = 0; i < n; i++) {
		s = sections[i]
		printf "\t\t\t\"%s\": {\n", s
		printf "\t\t\t\t\"reasoningEffort\": \"high\"\n"
		printf "\t\t\t}"
		if (i < n - 1)
			printf ",\n"
		else
			printf "\n"
	}

	printf "\t}\n"
	printf "}\n"
}
' "$INI_FILE" > "$OUT_FILE"

echo "✓  $OUT_FILE"
