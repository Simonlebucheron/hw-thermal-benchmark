#!/usr/bin/env bash

set -u -o pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${BENCH_CONFIG:-$ROOT_DIR/benchmark.config.json}"

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

value = data.get(key, default)
if value is None:
    print(default)
elif isinstance(value, bool):
    print("true" if value else "false")
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

usage() {
    cat <<'EOF'
Usage:
  ./scripts/benchmark.sh commands <label>
  ./scripts/benchmark.sh start <label>
  ./scripts/benchmark.sh stress [duration_seconds]
  ./scripts/benchmark.sh openbenchmark [cpu|gpu|mixed]
  ./scripts/benchmark.sh doctor

Examples:
  ./scripts/benchmark.sh commands before_cpu
  ./scripts/benchmark.sh start before_cpu
  ./scripts/benchmark.sh stress
  ./scripts/benchmark.sh openbenchmark mixed
EOF
}

print_commands() {
    local raw_label="$1"
    local label
    label="$(sanitize_label "$raw_label")"

    local scenario
    scenario="$(read_cfg "openbenchmark_scenario" "cpu")"

    echo "Terminal A (capture):"
    echo "./scripts/benchmark.sh start $label"
    echo
    echo "Terminal B (local stress-ng):"
    echo "./scripts/benchmark.sh stress"
    echo
    echo "Terminal B (OpenBenchmark):"
    echo "./scripts/benchmark.sh openbenchmark $scenario"
}

start_capture() {
    local raw_label="$1"
    local label
    label="$(sanitize_label "$raw_label")"

    local output_dir interval timestamp out_file mb_chip gpu_chip
    output_dir="$(read_cfg "output_dir" "data")"
    interval="$(read_cfg "interval_s" "1")"
    mb_chip="$(read_cfg "mb_chip_pattern" "auto")"
    gpu_chip="$(read_cfg "gpu_chip_pattern" "auto")"

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

    timestamp="$(date '+%Y%m%d_%H%M%S')"
    mkdir -p "$ROOT_DIR/$output_dir"
    out_file="$ROOT_DIR/$output_dir/${label}_${timestamp}.csv"

    echo "Starting capture"
    echo "  file: $out_file"
    echo "  interval_s: $interval"
    echo "  mb_chip_pattern: $mb_chip"
    echo "  gpu_chip_pattern: $gpu_chip"

    INTERVAL="$interval" \
    MB_CHIP_PATTERN="$mb_chip" \
    GPU_CHIP_PATTERN="$gpu_chip" \
    exec "$ROOT_DIR/logger_rpm.sh" "$out_file"
}

run_stress() {
    local duration="${1:-}"
    local cfg_duration cfg_cpu cfg_gpu
    cfg_duration="$(read_cfg "stress_duration_s" "900")"
    cfg_cpu="$(read_cfg "stress_cpu_workers" "0")"
    cfg_gpu="$(read_cfg "stress_gpu_workers" "1")"

    if [[ -z "$duration" ]]; then
        duration="$cfg_duration"
    fi

    CPU_WORKERS="$cfg_cpu" GPU_WORKERS="$cfg_gpu" exec "$ROOT_DIR/scripts/run_stress_ng.sh" "$duration"
}

run_openbenchmark() {
    local scenario="${1:-}"
    local cfg_scenario cfg_runs
    cfg_scenario="$(read_cfg "openbenchmark_scenario" "cpu")"
    cfg_runs="$(read_cfg "openbenchmark_runs" "3")"

    if [[ -z "$scenario" ]]; then
        scenario="$cfg_scenario"
    fi

    FORCE_TIMES_TO_RUN="$cfg_runs" exec "$ROOT_DIR/scripts/run_openbenchmark.sh" "$scenario"
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
    echo "  stress_duration_s: $(read_cfg "stress_duration_s" "900")"
    echo "  openbenchmark_scenario: $(read_cfg "openbenchmark_scenario" "cpu")"
    echo "  openbenchmark_runs: $(read_cfg "openbenchmark_runs" "3")"
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
        stress)
            run_stress "${2:-}"
            ;;
        openbenchmark)
            run_openbenchmark "${2:-}"
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