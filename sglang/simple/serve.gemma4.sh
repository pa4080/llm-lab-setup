#!/usr/bin/env bash
# serve.sh — SGLang server for Gemma-4-E4B-IT-Apostate (multimodal: text + vision + audio)
# Model: heterodoxin/gemma-4-e4b-it-apostate (9B, BF16, 17GB safetensors)
# GPU: RTX 3090 (24GB VRAM) | Context: 32K | Port: 1005

MODEL_FILE="../../models/heterodoxin/gemma-4-e4b-it-apostate"
SERVED_NAME="gemma-4-e4b-it-apostate"


export CUDA_HOME=/usr/local/cuda-12.8
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

nvcc --version

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

MODEL_DIR="$PROJECT_ROOT/huggingface/heterodoxin/gemma-4-e4b-it-apostate"
SERVED_NAME="gemma-4-e4b-it-apostate"
PORT=10005
PID_FILE="$SCRIPT_DIR/.server.pid"
LOG_FILE="$SCRIPT_DIR/serve.log"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ── System tuning ────────────────────────────────────────────────────────────
tune_system() {
	log_info "Tuning system for performance..."
	echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null || true
	sysctl -w vm.swappiness=0 2>/dev/null || true
	sysctl -w kernel.numa_balancing=0 2>/dev/null || true
	sysctl -w kernel.sched_migration_cost_ns=50000 2>/dev/null || true
}

# ── Pre-flight checks ───────────────────────────────────────────────────────
check_prereqs() {
	# SGLang installed
	if ! command -v sglang &>/dev/null && ! python3 -c "import sglang" 2>/dev/null; then
		log_error "SGLang is not installed. Install via: pip install sglang"
		exit 1
	fi

	# Model directory
	if [[ ! -d "$MODEL_DIR" ]]; then
		log_error "Model directory not found: $MODEL_DIR"
		log_warn "Download from: https://huggingface.co/heterodoxin/gemma-4-e4b-it-apostate"
		exit 1
	fi

	# Model weights
	if [[ ! -f "$MODEL_DIR/model.safetensors" ]]; then
		log_error "model.safetensors not found in $MODEL_DIR"
		exit 1
	fi

	# Port availability
	if ss -tlnp 2>/dev/null | grep -q ":${PORT} " || netstat -tlnp 2>/dev/null | grep -q ":${PORT} "; then
		log_error "Port $PORT is already in use."
		exit 1
	fi
}

# ── Launch server ───────────────────────────────────────────────────────────
start() {
	log_info "Checking prerequisites..."
	check_prereqs

	# Check if already running
	if [[ -f "$PID_FILE" ]]; then
		local pid
		pid=$(cat "$PID_FILE")
		if kill -0 "$pid" 2>/dev/null; then
			log_warn "Server already running (PID $pid). Use './serve.sh stop' first."
			exit 1
		else
			log_warn "Stale PID file found. Removing."
			rm -f "$PID_FILE"
		fi
	fi

	# System tuning
	tune_system

	# Environment
	export SGLANG_ENABLE_OVERLAP_PLAN_STREAM=1
	export SGLANG_SET_CPU_AFFINITY=1

	log_info "Starting SGLang server..."
	log_info "  Model: $SERVED_NAME"
	log_info "  Path:  $MODEL_DIR"
	log_info "  Port:  $PORT"
	log_info "  Multimodal: text + vision + audio"
	log_info "  Logs:  $LOG_FILE"
	echo ""

	# Launch in background
	# --kv-cache-dtype bfloat16
	nohup python3 -m sglang.launch_server \
    --model-path "$MODEL_DIR" \
    --served-model-name "$SERVED_NAME" \
    --port "$PORT" \
    --host 0.0.0.0 \
    --context-length 32768 \
    --mem-fraction-static 0.85 \
    --chunked-prefill-size 16384 \
    --max-prefill-tokens 32768 \
    --max-running-requests 8 \
    --cuda-graph-max-bs 8 \
    --cuda-graph-bs 1 2 4 6 8 \
    --enable-multimodal \
    --trust-remote-code \
    --watchdog-timeout 600 \
		--disable-cuda-graph \
    1>>"$LOG_FILE" 2>&1 &

	local pid=$!
	echo "$pid" > "$PID_FILE"
	log_info "Server launched (PID $pid)"
	log_info "Waiting for server to be ready..."

	# Wait for server to come up (up to 300s)
	local retries=60
	local wait_interval=5
	while (( retries > 0 )); do
		if curl -sf "http://localhost:${PORT}/health" &>/dev/null; then
			log_info "Server is ready at http://localhost:${PORT}"
			echo ""
			log_info "Quick test:"
			echo "  curl http://localhost:${PORT}/v1/completions \\"
			echo "    -H 'Content-Type: application/json' \\"
			echo "    -d '{\"model\": \"${SERVED_NAME}\", \"prompt\": \"What is 2+2?\", \"max_tokens\": 32}'"
			return 0
		fi
		(( retries-- ))
		sleep "$wait_interval"
	done

	log_error "Server did not become ready within $(( retries * wait_interval ))s. Check logs: $LOG_FILE"
	exit 1
}

# ── Stop server ─────────────────────────────────────────────────────────────
stop() {
	if [[ ! -f "$PID_FILE" ]]; then
		log_warn "No PID file found. Server may not be running."
		# Fallback: try to find process on port
		local pid
		pid=$(ss -tlnp 2>/dev/null | grep ":${PORT} " | grep -oP 'pid=\K[0-9]+' || true)
		if [[ -n "$pid" ]]; then
			log_info "Found process on port $PORT (PID $pid). Killing..."
			kill "$pid" 2>/dev/null || true
		fi
		return 0
	fi

	local pid
	pid=$(cat "$PID_FILE")
	if kill -0 "$pid" 2>/dev/null; then
		log_info "Stopping server (PID $pid)..."
		kill "$pid"
		sleep 2
		if kill -0 "$pid" 2>/dev/null; then
			log_warn "Process still running. Force killing..."
			kill -9 "$pid"
		fi
		log_info "Server stopped."
	else
		log_warn "Process $pid not found. Cleaning up."
	fi
	rm -f "$PID_FILE"
}

# ── Status ───────────────────────────────────────────────────────────────────
status() {
	if [[ -f "$PID_FILE" ]]; then
		local pid
		pid=$(cat "$PID_FILE")
		if kill -0 "$pid" 2>/dev/null; then
			log_info "Server running (PID $pid)"
			curl -sf "http://localhost:${PORT}/health" | head -c 200
			echo ""
		else
			log_warn "Server not running (stale PID file)"
		fi
	else
		log_info "Server not running (no PID file)"
	fi
}

# ── Logs ─────────────────────────────────────────────────────────────────────
logs() {
	if [[ -f "$LOG_FILE" ]]; then
		tail -f "$LOG_FILE"
	else
		log_warn "No log file found at $LOG_FILE"
	fi
}

# ── Main ────────────────────────────────────────────────────────────────────
case "${1:-start}" in
	start)
		start
		;;
	stop)
		stop
		;;
	restart)
		stop
		sleep 3
		start
		;;
	status)
		status
		;;
	logs)
		logs
		;;
	*)
		echo "Usage: $0 {start|stop|restart|status|logs}"
		exit 1
		;;
esac
