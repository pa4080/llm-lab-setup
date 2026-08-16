#!/bin/bash
# Generate pi.dev models.json from a router INI file.
# Usage: ./generate-json-pi.sh <ini-file> [output-dir]
#
# Reads LOCAL_URL, LOCAL_SERVER_NAME, LOCAL_API_KEY from .env.
# Outputs <ini-file>.json in <output-dir> (defaults to same dir as INI).
#
# Pi.dev format: { "providers": { "<name>": { baseUrl, api, apiKey, models: [...] } } }

set -euo pipefail

INI_FILE="${1:?Usage: $0 <router.ini> [output-dir]}"
INI_FILE="$(realpath "$INI_FILE")"
OUT_DIR="${2:-$(dirname "$INI_FILE")}"
OUT_FILE="${OUT_DIR}/$(basename "${INI_FILE%.ini}.json")"

# ── Load env vars (safe parser — no `source` to avoid ${input:...} errors) ─
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/env-helper.sh"

LOCAL_URL="$(get_env LOCAL_URL)"
LOCAL_SERVER_NAME="$(get_env LOCAL_SERVER_NAME)"
LOCAL_API_KEY="$(get_env LOCAL_API_KEY)"

: "${LOCAL_URL:?LOCAL_URL not set in .env}"
: "${LOCAL_SERVER_NAME:?LOCAL_SERVER_NAME not set in .env}"
: "${LOCAL_API_KEY:?LOCAL_API_KEY not set in .env}"

# Pi expects base URLs without /chat/completions (it appends based on api type)
PI_BASE_URL="${LOCAL_URL%/chat/completions}"

# Slugify provider key for pi.dev — must match auth.json key
# 'LLaMA.cpp Local' → 'llama-cpp-local'
PROVIDER_KEY="$(echo "$LOCAL_SERVER_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[. ]/-/g')"

# ── Parse INI into JSONL (one JSON object per section) ─────────────
# Each line: { "id": "<section>", "ctxSize": <number>, "hasMmproj": <bool> }
#
# A commented-out `; dummy-ctx-size = N` acts as a fallback ctx-size used only
# for JSON generation, for presets that have no real ctx-size because --fit
# auto-sizes it at runtime. It is never passed to llama-server.
#
# A commented-out `; client-reasoning-efforts = a, b, c` list overrides the
# supported reasoning_effort values in the generated thinkingLevelMap, and
# `; client-reasoning-effort-default = a` marks the default effort. Both stay
# commented, so they are never passed to llama-server.
parse_ini() {
	local sec="" ctx_size=0 dummy_ctx_size=0 has_mmproj=false reasoning_efforts="" reasoning_effort_default=""

	while IFS= read -r line; do
		line="${line//$'\r'/}"                     # strip \r

		# Commented-out dummy-ctx-size fallback hint (checked before the
		# generic comment-skip below).
		if [[ "$line" =~ ^[[:space:]]*\;[[:space:]]*dummy-ctx-size[[:space:]]*=[[:space:]]*([0-9]+) ]]; then
			dummy_ctx_size="${BASH_REMATCH[1]}"
			continue
		fi

		if [[ "$line" =~ ^[[:space:]]*\;[[:space:]]*client-ctx-size[[:space:]]*=[[:space:]]*([0-9]+) ]]; then
			client_ctx_size="${BASH_REMATCH[1]}"
			continue
		fi

		# Commented-out client-reasoning-effort*-default hint (checked before
		# the -efforts match: the two key names differ, order keeps the more
		# specific key first).
		if [[ "$line" =~ ^[[:space:]]*\;[[:space:]]*client-reasoning-effort-default[[:space:]]*=(.*)$ ]]; then
			reasoning_effort_default="${BASH_REMATCH[1]}"
			reasoning_effort_default="${reasoning_effort_default%%\;*}"  # strip trailing `; comment`
			reasoning_effort_default="${reasoning_effort_default#"${reasoning_effort_default%%[![:space:]]*}"}" # trim leading
			reasoning_effort_default="${reasoning_effort_default%"${reasoning_effort_default##*[![:space:]]}"}" # trim trailing
			continue
		fi

		# Commented-out client-reasoning-efforts hint (comma-separated list of
		# supported reasoning_effort values, e.g. `xhigh, medium, low, none`).
		if [[ "$line" =~ ^[[:space:]]*\;[[:space:]]*client-reasoning-efforts[[:space:]]*=(.*)$ ]]; then
			reasoning_efforts="${BASH_REMATCH[1]}"
			reasoning_efforts="${reasoning_efforts%%\;*}"              # strip trailing `; comment`
			reasoning_efforts="${reasoning_efforts#"${reasoning_efforts%%[![:space:]]*}"}" # trim leading
			reasoning_efforts="${reasoning_efforts%"${reasoning_efforts##*[![:space:]]}"}" # trim trailing
			continue
		fi

		[[ "$line" =~ ^[[:space:]]*\; ]] && continue  # comment
		[[ "$line" =~ ^[[:space:]]*$ ]] && continue   # blank

		# Section header [Name]
		if [[ "$line" =~ ^\[([^\]]+)\]$ ]]; then
			local new_sec="${BASH_REMATCH[1]}"
			new_sec="${new_sec#"${new_sec%%[![:space:]]*}"}"   # trim leading
			new_sec="${new_sec%"${new_sec##*[![:space:]]}"}"   # trim trailing
			[[ "$new_sec" == "*" ]] && continue           # skip [*] defaults
			# Emit previous section (if any)
			if [[ -n "$sec" ]]; then
				printf '{"id":"%s","ctxSize":%d,"hasMmproj":%s,"reasoningEfforts":"%s","reasoningEffortDefault":"%s"}\n' \
					"$sec" "$(( ctx_size > 0 ? (client_ctx_size > 0 ? client_ctx_size : ctx_size) : dummy_ctx_size ))" "$has_mmproj" "$reasoning_efforts" "$reasoning_effort_default"
			fi
			sec="$new_sec"
			ctx_size=0
			dummy_ctx_size=0
			client_ctx_size=0
			has_mmproj=false
			reasoning_efforts=""
			reasoning_effort_default=""
			continue
		fi

		# Key = value
		if [[ "$line" == *=* ]]; then
			key="${line%%=*}"
			val="${line#*=}"
			key="${key#"${key%%[![:space:]]*}"}"
			key="${key%"${key##*[![:space:]]}"}"
			val="${val#"${val%%[![:space:]]*}"}"
			val="${val%"${val##*[![:space:]]}"}"
			val="${val%%\;*}"                      # strip inline comment
			val="${val%"${val##*[![:space:]]}"}"   # trim trailing

			case "$key" in
				ctx-size) ctx_size="${val:-0}" ;;
				mmproj)   has_mmproj=true ;;
			esac
		fi
	done < "$INI_FILE"

	# Emit last section
	if [[ -n "$sec" ]]; then
		printf '{"id":"%s","ctxSize":%d,"hasMmproj":%s,"reasoningEfforts":"%s","reasoningEffortDefault":"%s"}\n' \
			"$sec" "$(( ctx_size > 0 ? (client_ctx_size > 0 ? client_ctx_size : ctx_size) : dummy_ctx_size ))" "$has_mmproj" "$reasoning_efforts" "$reasoning_effort_default"
	fi
}

# ── Build final JSON with jq (pi.dev models.json format) ─────────
# Pi reads ~/.pi/agent/models.json with { providers: { ... } } wrapper
#
# Per-model thinkingLevelMap derivation:
#   listed efforts    = parsed `client-reasoning-efforts` list
#   listed levels     = map identity (e.g. "xhigh" -> "xhigh")
#   unlisted levels   = null (hidden by pi)
#   "none" level      = maps to off: "none" (pi sends reasoning_effort: "none")
#   absent hint list  = fallback to the standard map (low/medium/high)
parse_ini | jq -s \
	--arg name     "$PROVIDER_KEY" \
	--arg baseUrl  "$PI_BASE_URL" \
	--arg apiKey   "$LOCAL_API_KEY" \
	'
	{
		providers: {
			($name): {
				baseUrl:  $baseUrl,
				api:      "openai-completions",
				apiKey:   $apiKey,
				models: [
					.[]
					| ( ( .reasoningEfforts // "" ) | split(",") | map(gsub("^[[:space:]]+|[[:space:]]+$"; "") | select(. != "")) ) as $efforts
					| ( if ($efforts | length) > 0
						then ( ( ["low", "medium", "high", "xhigh", "max"] | map(. as $e | { key: $e, value: (if ($efforts | index($e)) then $e else null end) }) | from_entries )
							+ { off: (if ($efforts | index("none")) then "none" else null end) } | { minimal: null } + . )
						else { minimal: null, low: "low", medium: "medium", high: "high", max: null } end ) as $map
					| {
						id:              .id,
						name:            .id,
						reasoning:       true,
						input:           (if .hasMmproj then ["text", "image"] else ["text"] end),
						contextWindow:   .ctxSize,
						maxTokens:       (.ctxSize / 4 | floor),
						thinkingLevelMap: $map,
						cost: {
							input:       0,
							output:      0,
							cacheRead:   0,
							cacheWrite:  0
						}
					}
				]
			}
		}
	}
	' > "$OUT_FILE"

echo "✓  $OUT_FILE"
