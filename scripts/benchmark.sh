#!/usr/bin/env bash

# Orchestrate capture, workload execution, and benchmark presets.

set -u -o pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${BENCH_CONFIG:-$ROOT_DIR/benchmark.config.json}"
RUN_LOGGER_PID=""
RUN_SENSOR_PANE_ID=""
RUN_CLEANUP_DONE=0

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1" >&2
        exit 1
    }
}

for cmd in python3 date mkdir sensors; do
    require_cmd "$cmd"
done

read_cfg() {
    local key="$1"
    local default_value="$2"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        printf '%s\n' "$default_value"
        return 0
    fi

    python3 - "$CONFIG_FILE" "$key" "$default_value" <<'PY'
import json
import sys

config_path, key, default = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(config_path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    print(default)
    raise SystemExit(0)

value = data
for part in key.split('.'):
    if isinstance(value, dict) and part in value:
        value = value[part]
    else:
        value = default
        break

if value is None:
    print(default)
elif isinstance(value, bool):
    print("true" if value else "false")
elif isinstance(value, list):
    print(",".join(str(item) for item in value))
else:
    print(value)
PY
}

detect_mb_chip() {
    sensors | awk '
        /^[[:alnum:]_.-]+-[[:alnum:]_.-]+-[[:xdigit:]]+$/ {
            chip = $0
            next
        }
        /^SYSTIN:/ && chip != "" {
            print chip
            exit
        }
    '
}

detect_gpu_chip() {
    sensors | awk '
        /^[[:alnum:]_.-]+-[[:alnum:]_.-]+-[[:xdigit:]]+$/ {
            chip = $0
            next
        }
        /^edge:/ && chip != "" {
            print chip
            exit
        }
    '
}

sanitize_label() {
    local label="$1"
    label="${label// /_}"
    label="$(printf '%s' "$label" | tr -cd 'A-Za-z0-9._-')"
    if [[ -z "$label" ]]; then
        label="run"
    fi
    printf '%s\n' "$label"
}

prompt_ambient_temperature() {
    local ambient_temp="${AMBIENT_TEMP_C:-}"

    if [[ -z "$ambient_temp" && -t 0 ]]; then
        printf 'Ambient temperature in degC [Enter to skip]: ' >&2
        if ! read -r -t 15 ambient_temp; then
            ambient_temp=""
            printf '\n' >&2
        fi
    fi

    printf '%s\n' "$ambient_temp"
}

usage() {
    cat <<'EOF'
Usage:
    ./scripts/benchmark.sh commands <label>
    ./scripts/benchmark.sh start <label>
    ./scripts/benchmark.sh load [cpu|gpu|system]
    ./scripts/benchmark.sh run <label> [cpu|gpu|system]
    ./scripts/benchmark.sh doctor

Examples:
    ./scripts/benchmark.sh commands cpu_hwstate1
    ./scripts/benchmark.sh start cpu_hwstate1
    ./scripts/benchmark.sh load
    ./scripts/benchmark.sh load cpu
    ./scripts/benchmark.sh run cpu_hwstate1 cpu
EOF
}

print_commands() {
    local raw_label="$1"
    local label
    label="$(sanitize_label "$raw_label")"

    local category
    category="$(read_cfg "openbenchmark.category" "cpu")"

    echo "Terminal A (capture):"
    echo "./scripts/benchmark.sh start $label"
    echo
    echo "Terminal B (workload - OpenBenchmark):"
    echo "./scripts/benchmark.sh load $category"
    echo
    echo "Single terminal (auto trigger before/after load):"
    echo "./scripts/benchmark.sh run $label $category"
}

detect_capture_chips() {
    local mb_chip="$1"
    local gpu_chip="$2"

    if [[ "$mb_chip" == "auto" ]]; then
        mb_chip="$(detect_mb_chip)"
    fi
    if [[ "$gpu_chip" == "auto" ]]; then
        gpu_chip="$(detect_gpu_chip)"
    fi

    if [[ -z "$mb_chip" || -z "$gpu_chip" ]]; then
        echo "Could not auto-detect chip patterns from sensors output." >&2
        echo "Set mb_chip_pattern and gpu_chip_pattern in benchmark.config.json." >&2
        exit 1
    fi

    printf '%s,%s\n' "$mb_chip" "$gpu_chip"
}

prepare_capture_context() {
    local raw_label="$1"
    local ambient_temp="$2"
    local chips mb_chip gpu_chip

    CAP_LABEL="$(sanitize_label "$raw_label")"
    CAP_OUTPUT_DIR="$(read_cfg "output_dir" "data")"
    CAP_INTERVAL="$(read_cfg "interval_s" "1")"
    CAP_GPU_POWER_ENABLED="$(read_cfg "gpu_power_enabled" "true")"
    mb_chip="$(read_cfg "mb_chip_pattern" "auto")"
    gpu_chip="$(read_cfg "gpu_chip_pattern" "auto")"

    chips="$(detect_capture_chips "$mb_chip" "$gpu_chip")"
    CAP_MB_CHIP="${chips%%,*}"
    CAP_GPU_CHIP="${chips#*,}"

    CAP_TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
    mkdir -p "$ROOT_DIR/$CAP_OUTPUT_DIR"
    CAP_OUT_FILE="$ROOT_DIR/$CAP_OUTPUT_DIR/${CAP_LABEL}_${CAP_TIMESTAMP}.csv"
    CAP_META_FILE="${CAP_OUT_FILE%.csv}.meta"

    {
        printf 'label=%s\n' "$CAP_LABEL"
        printf 'timestamp=%s\n' "$CAP_TIMESTAMP"
        printf 'ambient_temp_c=%s\n' "${ambient_temp:-}"
    } > "$CAP_META_FILE"
}

start_logger() {
    local mode="$1"
    local live_preview="${2:-false}"

    if [[ "$mode" == "foreground" ]]; then
        INTERVAL="$CAP_INTERVAL" \
        MB_CHIP_PATTERN="$CAP_MB_CHIP" \
        GPU_CHIP_PATTERN="$CAP_GPU_CHIP" \
        GPU_POWER_ENABLED="$CAP_GPU_POWER_ENABLED" \
        exec "$ROOT_DIR/logger_rpm.sh" "$CAP_OUT_FILE"
    fi

    INTERVAL="$CAP_INTERVAL" \
    MB_CHIP_PATTERN="$CAP_MB_CHIP" \
    GPU_CHIP_PATTERN="$CAP_GPU_CHIP" \
    GPU_POWER_ENABLED="$CAP_GPU_POWER_ENABLED" \
    LIVE_TERMINAL="$live_preview" \
    "$ROOT_DIR/logger_rpm.sh" "$CAP_OUT_FILE" &
}

cleanup_run_resources() {
    if (( RUN_CLEANUP_DONE == 1 )); then
        return 0
    fi
    RUN_CLEANUP_DONE=1

    if [[ -n "$RUN_LOGGER_PID" ]]; then
        stop_process_with_timeout "$RUN_LOGGER_PID" "logger_rpm" 5
        RUN_LOGGER_PID=""
    fi

    if [[ -n "$RUN_SENSOR_PANE_ID" ]] && command -v tmux >/dev/null 2>&1; then
        tmux kill-pane -t "$RUN_SENSOR_PANE_ID" >/dev/null 2>&1 || true
        RUN_SENSOR_PANE_ID=""
    fi
}

stop_process_with_timeout() {
    local pid="$1"
    local name="$2"
    local timeout_s="${3:-5}"
    local ticks i

    if [[ -z "$pid" ]]; then
        return 0
    fi
    if ! [[ "$timeout_s" =~ ^[0-9]+$ ]] || (( timeout_s <= 0 )); then
        timeout_s=5
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
        wait "$pid" 2>/dev/null || true
        return 0
    fi

    kill -TERM "$pid" 2>/dev/null || true
    ticks=$((timeout_s * 10))
    for ((i = 0; i < ticks; i++)); do
        if ! kill -0 "$pid" 2>/dev/null; then
            wait "$pid" 2>/dev/null || true
            return 0
        fi
        sleep 0.1
    done

    echo "Process $name ($pid) did not exit after ${timeout_s}s, forcing kill." >&2
    kill -KILL "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
}

handle_run_signal() {
    local signal_name="$1"
    local exit_code=130
    if [[ "$signal_name" == "TERM" ]]; then
        exit_code=143
    fi

    cleanup_run_resources
    trap - INT TERM EXIT
    exit "$exit_code"
}

start_sensor_tmux_pane() {
    local tail_cmd pane_id

    if ! command -v tmux >/dev/null 2>&1; then
        echo "sensor_display_mode=tmux requested but tmux is not installed; continuing without live sensor pane." >&2
        return 0
    fi

    if [[ -z "${TMUX:-}" ]]; then
        echo "sensor_display_mode=tmux requested but no active tmux session detected; continuing without live sensor pane." >&2
        return 0
    fi

    tail_cmd="tail -n +2 -f \"$CAP_OUT_FILE\" | awk -F, '{printf \"[t=%ss] CPU=%sC MB=%sC GPU=%sC GPU_PWR=%sW CPU_PWR=%sW PWR=%sW\\n\", \$1, \$3, \$4, \$5, \$8, \$13, \$14}'"
    pane_id="$(tmux split-window -v -P -F '#{pane_id}' "$tail_cmd")"
    RUN_SENSOR_PANE_ID="$pane_id"

    if [[ -n "${TMUX_PANE:-}" ]]; then
        tmux select-pane -t "$TMUX_PANE" >/dev/null 2>&1 || true
    fi
}

print_capture_info() {
    local ambient_temp="$1"

    echo "  file: $CAP_OUT_FILE"
    if [[ -n "$ambient_temp" ]]; then
        echo "  ambient_temp_c: $ambient_temp"
    else
        echo "  ambient_temp_c: skipped"
    fi
    echo "  interval_s: $CAP_INTERVAL"
    echo "  mb_chip_pattern: $CAP_MB_CHIP"
    echo "  gpu_chip_pattern: $CAP_GPU_CHIP"
    echo "  gpu_power_enabled: $CAP_GPU_POWER_ENABLED"
    echo "  meta_file: $CAP_META_FILE"
}

start_capture() {
    local raw_label="$1"
    local ambient_temp
    ambient_temp="$(prompt_ambient_temperature)"
    prepare_capture_context "$raw_label" "$ambient_temp"

    echo "Starting capture"
    print_capture_info "$ambient_temp"

    start_logger "foreground"
}

run_openbenchmark() {
    local category="${1:-}"
    local cfg_category cfg_runs cfg_tests tests_csv
    cfg_category="$(read_cfg "openbenchmark.category" "cpu")"
    cfg_runs="$(read_cfg "openbenchmark.runs" "3")"
    cfg_tests="$(read_cfg "openbenchmark.tests" "")"

    if [[ -z "$category" ]]; then
        category="$cfg_category"
    fi

    # If category is explicitly overridden, avoid forcing tests from config
    # unless the caller passed OPENBENCHMARK_TESTS_CSV manually.
    if [[ -n "${OPENBENCHMARK_TESTS_CSV:-}" ]]; then
        tests_csv="${OPENBENCHMARK_TESTS_CSV:-}"
    elif [[ -n "${1:-}" && "$category" != "$cfg_category" ]]; then
        tests_csv=""
    else
        tests_csv="$cfg_tests"
    fi

    FORCE_TIMES_TO_RUN="$cfg_runs" OPENBENCHMARK_TESTS_CSV="$tests_csv" "$ROOT_DIR/scripts/run_openbenchmark.sh" "$category"
}

sleep_with_message() {
    local seconds="$1"
    local message="$2"

    if ! [[ "$seconds" =~ ^[0-9]+$ ]]; then
        echo "Invalid seconds value: $seconds" >&2
        return 1
    fi
    if (( seconds <= 0 )); then
        return 0
    fi

    echo "$message (${seconds}s)"
    sleep "$seconds"
}

run_capture_and_load() {
    local raw_label="$1"
    local category="${2:-}"
    local ambient_temp
    local pre_trigger_s post_trigger_s live_preview sensor_display_mode logger_live

    pre_trigger_s="$(read_cfg "trigger_pre_s" "60")"
    post_trigger_s="$(read_cfg "trigger_post_s" "60")"
    live_preview="$(read_cfg "live_preview" "true")"
    sensor_display_mode="$(read_cfg "sensor_display_mode" "off")"
    ambient_temp="$(prompt_ambient_temperature)"
    prepare_capture_context "$raw_label" "$ambient_temp"

    RUN_LOGGER_PID=""
    RUN_SENSOR_PANE_ID=""
    RUN_CLEANUP_DONE=0
    trap 'handle_run_signal INT' INT
    trap 'handle_run_signal TERM' TERM
    trap 'cleanup_run_resources' EXIT

    case "$sensor_display_mode" in
        off)
            logger_live="false"
            ;;
        inline)
            logger_live="$live_preview"
            ;;
        tmux)
            logger_live="false"
            ;;
        *)
            echo "Unknown sensor_display_mode: $sensor_display_mode (expected: off|inline|tmux)." >&2
            trap - INT TERM EXIT
            return 1
            ;;
    esac

    echo "Starting automated benchmark"
    print_capture_info "$ambient_temp"
    echo "  category: ${category:-auto}"
    echo "  pre_trigger_s: $pre_trigger_s"
    echo "  post_trigger_s: $post_trigger_s"
    echo "  live_preview: $live_preview"
    echo "  sensor_display_mode: $sensor_display_mode"

    local load_rc=0
    start_logger "background" "$logger_live"
    RUN_LOGGER_PID=$!

    if [[ "$sensor_display_mode" == "tmux" ]]; then
        start_sensor_tmux_pane
    fi

    if ! sleep_with_message "$pre_trigger_s" "Stabilizing before load"; then
        cleanup_run_resources
        trap - INT TERM EXIT
        return 1
    fi

    if ! run_openbenchmark "$category"; then
        load_rc=$?
    fi

    if ! sleep_with_message "$post_trigger_s" "Cooling capture after load"; then
        load_rc=1
    fi

    cleanup_run_resources
    trap - INT TERM EXIT

    echo "Capture completed: $CAP_OUT_FILE"
    if (( load_rc != 0 )); then
        echo "Workload finished with non-zero status: $load_rc" >&2
        return "$load_rc"
    fi
}

doctor() {
    echo "Config file: $CONFIG_FILE"
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "status: found"
    else
        echo "status: missing (using defaults)"
    fi
    echo
    echo "Detected sensors chips:"
    echo "  mb_chip_pattern: $(detect_mb_chip || true)"
    echo "  gpu_chip_pattern: $(detect_gpu_chip || true)"
    echo
    echo "Effective defaults:"
    echo "  interval_s: $(read_cfg "interval_s" "1")"
    echo "  output_dir: $(read_cfg "output_dir" "data")"
    echo "  gpu_power_enabled: $(read_cfg "gpu_power_enabled" "true")"
    echo "  trigger_pre_s: $(read_cfg "trigger_pre_s" "60")"
    echo "  trigger_post_s: $(read_cfg "trigger_post_s" "60")"
    echo "  live_preview: $(read_cfg "live_preview" "true")"
    echo "  sensor_display_mode: $(read_cfg "sensor_display_mode" "off")"
    echo "  openbenchmark.category: $(read_cfg "openbenchmark.category" "cpu")"
    echo "  openbenchmark.runs: $(read_cfg "openbenchmark.runs" "3")"
    echo "  openbenchmark.tests: $(read_cfg "openbenchmark.tests" "")"
}

main() {
    local cmd="${1:-}"
    case "$cmd" in
        commands)
            if [[ -z "${2:-}" ]]; then
                echo "Missing label." >&2
                usage
                exit 1
            fi
            print_commands "$2"
            ;;
        start)
            if [[ -z "${2:-}" ]]; then
                echo "Missing label." >&2
                usage
                exit 1
            fi
            start_capture "$2"
            ;;
        load)
            run_openbenchmark "${2:-}"
            ;;
        run)
            if [[ -z "${2:-}" ]]; then
                echo "Missing label." >&2
                usage
                exit 1
            fi
            run_capture_and_load "$2" "${3:-}"
            ;;
        doctor)
            doctor
            ;;
        -h|--help|help|"")
            usage
            ;;
        *)
            echo "Unknown command: $cmd" >&2
            usage
            exit 1
            ;;
    esac
}

main "$@"