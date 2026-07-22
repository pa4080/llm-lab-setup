#!/bin/bash
# Generate chatLanguageModels JSON from a router INI file.
# Usage: ./generate-json-copilot.sh <ini-file> [output-dir]
#
# Reads LOCAL_URL, LOCAL_SERVER_NAME, LOCAL_API_KEY from .env.
# Outputs <ini-file>.json in <output-dir> (defaults to same dir as INI).

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

INI_BASENAME="$(basename "${INI_FILE%.ini}")"
SERVER_NAME="$LOCAL_SERVER_NAME $INI_BASENAME"

# ── Parse INI into JSONL (one JSON object per section) ─────────────
# Each line: { "id": "<section>", "ctxSize": <number>, "hasMmproj": <bool> }
#
# A commented-out `; dummy-ctx-size = N` acts as a fallback ctx-size used only
# for JSON generation (maxInputTokens/maxOutputTokens), for presets that have
# no real ctx-size because --fit auto-sizes it at runtime (e.g. VBR "MAXCTX"
# presets). It is never passed to llama-server (stays commented in router.ini).
parse_ini() {
	local sec="" ctx_size=0 dummy_ctx_size=0 has_mmproj=false

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
				printf '{"id":"%s","ctxSize":%d,"hasMmproj":%s}\n' \
					"$sec" "$(( ctx_size > 0 ? (client_ctx_size > 0 ? client_ctx_size : ctx_size) : dummy_ctx_size ))" "$has_mmproj"
			fi
			sec="$new_sec"
			ctx_size=0
			dummy_ctx_size=0
			client_ctx_size=0
			has_mmproj=false
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
		printf '{"id":"%s","ctxSize":%d,"hasMmproj":%s}\n' \
			"$sec" "$(( ctx_size > 0 ? (client_ctx_size > 0 ? client_ctx_size : ctx_size) : dummy_ctx_size ))" "$has_mmproj"
	fi
}

# ── Build final JSON with jq ───────────────────────────────────────
parse_ini | jq -s \
	--arg name       "$SERVER_NAME" \
	--arg vendor     "customendpoint" \
	--arg apiKey     "$LOCAL_API_KEY" \
	--arg url        "$LOCAL_URL" \
	'
	{
		name:   $name,
		vendor: $vendor,
		apiKey: $apiKey,
		models: [
			.[] | {
				id:                    .id,
				name:                  .id,
				url:                   $url,
				toolCalling:           true,
				vision:                .hasMmproj,
				streaming:             true,
				apiType:               "chat-completions",
				editTools:             [
					"apply-patch",
					"code-rewrite",
					"find-replace",
					"multi-find-replace"
				],
				thinking:              true,
				supportsReasoningEffort: ["low", "medium", "high"],
				reasoningEffortFormat: "chat-completions",
				zeroDataRetentionEnabled: false,
				maxInputTokens:        (.ctxSize * 3 / 4 | floor),
				maxOutputTokens:       (.ctxSize * 1 / 4 | floor)
			}
		],
		settings: (
			[ .[] | { (.id): { reasoningEffort: "high" } } ] | add // {}
		)
	}
	' > "$OUT_FILE"

echo "✓  $OUT_FILE"
