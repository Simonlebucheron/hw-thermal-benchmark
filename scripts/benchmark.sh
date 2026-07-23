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
  ./scripts/benchmark.sh doctor

Examples:
    ./scripts/benchmark.sh commands cpu_hwstate1
    ./scripts/benchmark.sh start cpu_hwstate1
    ./scripts/benchmark.sh load
    ./scripts/benchmark.sh load cpu
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
}

start_capture() {
    local raw_label="$1"
    local label
    label="$(sanitize_label "$raw_label")"

    local output_dir interval timestamp out_file meta_file mb_chip gpu_chip gpu_power_enabled ambient_temp
    output_dir="$(read_cfg "output_dir" "data")"
    interval="$(read_cfg "interval_s" "1")"
    mb_chip="$(read_cfg "mb_chip_pattern" "auto")"
    gpu_chip="$(read_cfg "gpu_chip_pattern" "auto")"
    gpu_power_enabled="$(read_cfg "gpu_power_enabled" "true")"
    ambient_temp="$(prompt_ambient_temperature)"

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
    meta_file="${out_file%.csv}.meta"

    {
        printf 'label=%s\n' "$label"
        printf 'timestamp=%s\n' "$timestamp"
        printf 'ambient_temp_c=%s\n' "${ambient_temp:-}"
    } > "$meta_file"

    echo "Starting capture"
    echo "  file: $out_file"
    if [[ -n "$ambient_temp" ]]; then
        echo "  ambient_temp_c: $ambient_temp"
    else
        echo "  ambient_temp_c: skipped"
    fi
    echo "  interval_s: $interval"
    echo "  mb_chip_pattern: $mb_chip"
    echo "  gpu_chip_pattern: $gpu_chip"
    echo "  gpu_power_enabled: $gpu_power_enabled"
    echo "  meta_file: $meta_file"

    INTERVAL="$interval" \
    MB_CHIP_PATTERN="$mb_chip" \
    GPU_CHIP_PATTERN="$gpu_chip" \
    GPU_POWER_ENABLED="$gpu_power_enabled" \
    exec "$ROOT_DIR/logger_rpm.sh" "$out_file"
}

run_openbenchmark() {
    local category="${1:-}"
    local cfg_category cfg_runs cfg_tests
    cfg_category="$(read_cfg "openbenchmark.category" "cpu")"
    cfg_runs="$(read_cfg "openbenchmark.runs" "3")"
    cfg_tests="$(read_cfg "openbenchmark.tests" "")"

    if [[ -z "$category" ]]; then
        category="$cfg_category"
    fi

    FORCE_TIMES_TO_RUN="$cfg_runs" OPENBENCHMARK_TESTS_CSV="$cfg_tests" exec "$ROOT_DIR/scripts/run_openbenchmark.sh" "$category"
}

run_load() {
    run_openbenchmark "${1:-}"
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
            run_load "${2:-}"
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