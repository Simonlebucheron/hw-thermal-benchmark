#!/usr/bin/env bash

set -u -o pipefail

INTERVAL="${INTERVAL:-1}"
OUTFILE="${1:-benchmark.csv}"
CPU_LABEL="${CPU_LABEL:-Package id 0:}"
MB_CHIP_PATTERN="${MB_CHIP_PATTERN:-nct6791-isa-0290}"
GPU_CHIP_PATTERN="${GPU_CHIP_PATTERN:-amdgpu-pci-0300}"
GPU_POWER_ENABLED="${GPU_POWER_ENABLED:-true}"

CSV_HEADER="time_s,timestamp,cpu_temp_c,mb_temp_c,gpu_edge_c,gpu_junction_c,gpu_mem_c,gpu_power_w,cpu_fan_rpm,case_fan1_rpm,case_fan2_rpm,gpu_fan_rpm"
CSV_NAN_ROW="NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN"

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1" >&2
        exit 1
    }
}

for cmd in sensors awk date sleep dirname mkdir; do
    require_cmd "$cmd"
done

if ! [[ "$INTERVAL" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "INTERVAL must be a positive number (seconds)." >&2
    exit 1
fi

mkdir -p "$(dirname -- "$OUTFILE")"
printf '%s\n' "$CSV_HEADER" > "$OUTFILE"

START=$(date +%s)

cleanup() {
    echo "Stopped logger. Output: $OUTFILE" >&2
    exit 0
}

extract_metrics() {
    awk -v cpu_label="$CPU_LABEL" -v mb_chip_pattern="$MB_CHIP_PATTERN" -v gpu_chip_pattern="$GPU_CHIP_PATTERN" -v gpu_power_enabled="$GPU_POWER_ENABLED" '
        function clean_num(v) {
            gsub(/[^0-9.\-]/, "", v)
            return (v == "" ? "NaN" : v)
        }

        BEGIN {
            section = ""
            cpu_temp = mb_temp = gpu_edge = gpu_junction = gpu_mem = "NaN"
            gpu_power = cpu_fan = case_fan1 = case_fan2 = gpu_fan = "NaN"
        }

        index($0, cpu_label) == 1 {
            cpu_temp = clean_num($4)
        }

        $0 ~ mb_chip_pattern { section = "mb"; next }
        $0 ~ gpu_chip_pattern { section = "gpu"; next }
        /^$/ { section = ""; next }

        section == "mb" && /^SYSTIN:/ { mb_temp = clean_num($2) }
        section == "mb" && /^fan1:/ { cpu_fan = clean_num($2) }
        section == "mb" && /^fan2:/ { case_fan1 = clean_num($2) }
        section == "mb" && /^fan3:/ { case_fan2 = clean_num($2) }

        section == "gpu" && /^edge:/ { gpu_edge = clean_num($2) }
        section == "gpu" && /^junction:/ { gpu_junction = clean_num($2) }
        section == "gpu" && /^mem:/ { gpu_mem = clean_num($2) }
        section == "gpu" && gpu_power_enabled == "true" && /^PPT:/ { gpu_power = clean_num($2) }
        section == "gpu" && /^fan1:/ { gpu_fan = clean_num($2) }

        END {
            printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s", cpu_temp, mb_temp, gpu_edge, gpu_junction, gpu_mem, gpu_power, cpu_fan, case_fan1, case_fan2, gpu_fan
        }
    '
}

trap cleanup INT TERM

while true; do
    now=$(date +%s)
    elapsed=$((now - START))
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    sensors_output=""
    if ! sensors_output="$(sensors 2>/dev/null)"; then
        sensors_output=""
    fi

    if [[ -n "$sensors_output" ]]; then
        metrics="$(printf '%s\n' "$sensors_output" | extract_metrics)"
    else
        metrics="$CSV_NAN_ROW"
    fi

    printf '%s,%s,%s\n' "$elapsed" "$timestamp" "$metrics" >> "$OUTFILE"
    sleep "$INTERVAL"
done
