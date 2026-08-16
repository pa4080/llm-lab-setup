#!/bin/bash
# Generate chatLanguageModels.json (Copilot) and models.json (pi.dev)
# from omniroute-models.json (OpenAI-compatible model list).
#
# Usage: omniroute-generate-config.sh [options]
#
# Options:
#   --fetch              Fetch models from URL instead of local file
#   --url URL            Override OMNIROUTE_URL (default from .env)
#   --copilot-dir DIR    Output dir for Copilot JSON (default: omniroute/confs/copilot/)
#   --pi-dir DIR         Output dir for Pi JSON (default: omniroute/confs/pi/)
#   --input FILE         Input JSON file (default: omniroute/omniroute-models.json)
#   -h, --help           Show this help
#
# Reads LOCAL_URL, LOCAL_SERVER_NAME, LOCAL_API_KEY from .env.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Defaults ──────────────────────────────────────────────────────────────────
FETCH_MODE=false
OMNIROUTE_URL=""
COPILOT_DIR=""
PI_DIR=""
INPUT_FILE=""

# ── Argument parsing ───────────────────────────────────────────────────────────
show_help() {
	sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# //'
	exit 0
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--fetch) FETCH_MODE=true; shift ;;
		--url) OMNIROUTE_URL="$2"; shift 2 ;;
		--copilot-dir) COPILOT_DIR="$2"; shift 2 ;;
		--pi-dir) PI_DIR="$2"; shift 2 ;;
		--input) INPUT_FILE="$2"; shift 2 ;;
		-h|--help) show_help ;;
		*) echo "Unknown option: $1" >&2; exit 1 ;;
	esac
done

# ── Load env vars ──────────────────────────────────────────────────────────────
source "$SCRIPT_DIR/env-helper.sh"

LOCAL_URL="$(get_env LOCAL_URL)"
LOCAL_SERVER_NAME="$(get_env LOCAL_SERVER_NAME)"
LOCAL_API_KEY="$(get_env LOCAL_API_KEY)"
OMNIROUTE_URL="${OMNIROUTE_URL:-$(get_env OMNIROUTE_URL 2>/dev/null || echo "")}"

: "${LOCAL_URL:?LOCAL_URL not set in .env}"
: "${LOCAL_SERVER_NAME:?LOCAL_SERVER_NAME not set in .env}"
: "${LOCAL_API_KEY:?LOCAL_API_KEY not set in .env}"

# ── Set output directories ─────────────────────────────────────────────────────
COPILOT_DIR="${COPILOT_DIR:-$PROJECT_ROOT/omniroute/confs/copilot}"
PI_DIR="${PI_DIR:-$PROJECT_ROOT/omniroute/confs/pi}"
INPUT_FILE="${INPUT_FILE:-$PROJECT_ROOT/omniroute/omniroute-models.json}"

# ── Acquire input JSON ─────────────────────────────────────────────────────────
if [[ "$FETCH_MODE" == true ]]; then
	: "${OMNIROUTE_URL:?--fetch requires --url or OMNIROUTE_URL in .env}"
	echo "Fetching models from $OMNIROUTE_URL..." >&2
	MODELS_JSON="$(curl -sS "$OMNIROUTE_URL")"
else
	if [[ ! -f "$INPUT_FILE" ]]; then
		echo "ERROR: Input file not found: $INPUT_FILE" >&2
		exit 1
	fi
	MODELS_JSON="$(cat "$INPUT_FILE")"
fi

# ── Validate JSON structure ────────────────────────────────────────────────────
if ! echo "$MODELS_JSON" | jq -e '(.object == "list") and (.data | length > 0)' >/dev/null 2>&1; then
	echo "ERROR: Invalid OpenAI-compatible model list (expected {object: 'list', data: [...]})" >&2
	exit 1
fi

# ── Generate Copilot chatLanguageModels.json ────────────────────────────────────
# Output: [{name, vendor, apiKey, models: [...], settings: {...}}]
generate_copilot_json() {
	echo "$MODELS_JSON" | jq --arg url "$LOCAL_URL" --arg name "$LOCAL_SERVER_NAME" --arg key "$LOCAL_API_KEY" '
		[{
			name: $name,
			vendor: "omniroute",
			apiKey: $key,
			baseUrl: $url,
			models: [.data[] | {
				id: .id,
				name: .id,
				maxInputTokens: (
					if .max_input_tokens and .max_output_tokens and .max_input_tokens > 0 then (.max_input_tokens - .max_output_tokens)
					elif .context_length and .context_length > 0 then ((.context_length * 0.75) | floor)
					else null
					end
				),
				maxOutputTokens: (
					if .max_output_tokens and .max_output_tokens > 0 then .max_output_tokens
					elif .context_length and .context_length > 0 then ((.context_length * 0.25) | floor)
					else null
					end
				),
				supportsToolCalls: (.capabilities.tool_calling // false),
				supportsReasoningEffort: (
					if .capabilities.effort_tiers then .capabilities.effort_tiers
					elif .capabilities.reasoning then ["low", "medium", "high"]
					else null
					end
				),
				vision: (.capabilities.vision // false),
				inputModalities: (
					if .input_modalities then .input_modalities
					elif (.capabilities.vision // false) then ["text", "image"]
					else ["text"]
					end
				)
			}],
			settings: {
				caching: false,
				seed: -1,
				top_p: 1,
				temperature: 0
			}
		}]
	'
}

# ── Generate Pi models.json ────────────────────────────────────────────────────
# Output: {providers: {"<slug>": {baseUrl, api, apiKey, models: [...]}}}
generate_pi_json() {
	# Pi expects base URLs without /chat/completions
	local pi_base_url="${LOCAL_URL%/chat/completions}"
	# Slugify provider key: 'LLaMA.cpp Local' → 'llama-cpp-local'
	local provider_key="$(echo "$LOCAL_SERVER_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[. ]/-/g')"

	echo "$MODELS_JSON" | jq --arg url "$pi_base_url" --arg key "$LOCAL_API_KEY" --arg slug "$provider_key" '
		{
			providers: {
				($slug): {
					baseUrl: $url,
					api: "openai",
					apiKey: $key,
					models: [.data[] | {
						id: .id,
						name: .id,
						contextWindow: (.context_length // null),
						maxInputTokens: (
							if .max_input_tokens and .max_output_tokens and .max_input_tokens > 0 then (.max_input_tokens - .max_output_tokens)
							elif .context_length and .context_length > 0 then ((.context_length * 0.75) | floor)
							else null
							end
						),
						maxOutputTokens: (
							if .max_output_tokens and .max_output_tokens > 0 then .max_output_tokens
							elif .context_length and .context_length > 0 then ((.context_length * 0.25) | floor)
							else null
							end
						),
						input: (
							if .input_modalities then .input_modalities
							elif (.capabilities.vision // false) then ["text", "image"]
							else ["text"]
							end
						),
						supportsToolCalls: (.capabilities.tool_calling // false)
					}]
				}
			}
		}
	'
}

# ── Create output directories ──────────────────────────────────────────────────
mkdir -p "$COPILOT_DIR" "$PI_DIR"

# ── Generate and write outputs ─────────────────────────────────────────────────
COPILOT_OUT="$COPILOT_DIR/0-chatLanguageModels.json"
PI_OUT="$PI_DIR/0-pi-models.json"

echo "Generating Copilot JSON..." >&2
generate_copilot_json > "$COPILOT_OUT"

echo "Generating Pi JSON..." >&2
generate_pi_json > "$PI_OUT"

# ── Verify outputs ──────────────────────────────────────────────────────────────
echo "" >&2
echo "Generated:" >&2
echo "  Copilot: $COPILOT_OUT ($(jq ".[0].models | length" "$COPILOT_OUT") models)" >&2
echo "  Pi:      $PI_OUT ($(jq ".providers | to_entries[0].value.models | length" "$PI_OUT") models)" >&2

# ── Summary stats ───────────────────────────────────────────────────────────────
echo "" >&2
echo "Model capabilities:" >&2
echo "$MODELS_JSON" | jq -r '
	.data |
	"  Vision: \([.[] | select(.capabilities.vision == true)] | length)",
	"  Tool calling: \([.[] | select(.capabilities.tool_calling == true)] | length)",
	"  Reasoning: \([.[] | select(.capabilities.reasoning == true)] | length)"
' >&2
