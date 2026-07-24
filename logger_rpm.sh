#!/usr/bin/env bash

# Capture lm-sensors data to CSV for thermal benchmark runs.

set -u -o pipefail

INTERVAL="${INTERVAL:-1}"
OUTFILE="${1:-benchmark.csv}"
CPU_LABEL="${CPU_LABEL:-Package id 0:}"
MB_CHIP_PATTERN="${MB_CHIP_PATTERN:-nct6791-isa-0290}"
GPU_CHIP_PATTERN="${GPU_CHIP_PATTERN:-amdgpu-pci-0300}"
GPU_POWER_ENABLED="${GPU_POWER_ENABLED:-true}"
LIVE_TERMINAL="${LIVE_TERMINAL:-false}"
CPU_POWER_RAPL_ENABLED="${CPU_POWER_RAPL_ENABLED:-true}"

CSV_HEADER="time_s,timestamp,cpu_temp_c,mb_temp_c,gpu_edge_c,gpu_junction_c,gpu_mem_c,gpu_power_w,cpu_fan_rpm,case_fan1_rpm,case_fan2_rpm,gpu_fan_rpm,cpu_power_w,platform_power_w"
CSV_NAN_ROW="NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN"

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1" >&2
        exit 1
    }
}

for cmd in sensors awk date sleep dirname mkdir cat find head; do
    require_cmd "$cmd"
done

if ! [[ "$INTERVAL" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "INTERVAL must be a positive number (seconds)." >&2
    exit 1
fi

mkdir -p "$(dirname -- "$OUTFILE")"
printf '%s\n' "$CSV_HEADER" > "$OUTFILE"

START=$(date +%s)
PREV_CPU_ENERGY_UJ=""
PREV_CPU_ENERGY_TS=""
CPU_RAPL_ENERGY_UJ=""
CPU_RAPL_MAX_UJ=""

setup_cpu_rapl() {
    if [[ "$CPU_POWER_RAPL_ENABLED" != "true" ]]; then
        return 0
    fi

    local energy_file max_file
    energy_file="$(find /sys/class/powercap -type f -name 'energy_uj' 2>/dev/null | head -n 1 || true)"
    if [[ -z "$energy_file" || ! -r "$energy_file" ]]; then
        return 0
    fi

    max_file="${energy_file%/energy_uj}/max_energy_range_uj"
    CPU_RAPL_ENERGY_UJ="$energy_file"
    if [[ -r "$max_file" ]]; then
        CPU_RAPL_MAX_UJ="$(cat "$max_file" 2>/dev/null || true)"
    fi
}

sum_power_values() {
    local a="$1"
    local b="$2"

    awk -v a="$a" -v b="$b" 'BEGIN {
        va = (a ~ /^-?[0-9]+([.][0-9]+)?$/)
        vb = (b ~ /^-?[0-9]+([.][0-9]+)?$/)

        if (!va && !vb) {
            print "NaN"
            exit
        }
        if (!va) {
            printf "%.3f", b + 0.0
            exit
        }
        if (!vb) {
            printf "%.3f", a + 0.0
            exit
        }

        printf "%.3f", (a + 0.0) + (b + 0.0)
    }'
}

read_cpu_power_rapl() {
    if [[ -z "$CPU_RAPL_ENERGY_UJ" ]]; then
        printf 'NaN\n'
        return 0
    fi

    local now_ts current_energy delta_uj delta_s max_uj
    now_ts="$(date +%s)"
    current_energy="$(cat "$CPU_RAPL_ENERGY_UJ" 2>/dev/null || true)"
    if ! [[ "$current_energy" =~ ^[0-9]+$ ]]; then
        printf 'NaN\n'
        return 0
    fi

    if [[ -z "$PREV_CPU_ENERGY_UJ" || -z "$PREV_CPU_ENERGY_TS" ]]; then
        PREV_CPU_ENERGY_UJ="$current_energy"
        PREV_CPU_ENERGY_TS="$now_ts"
        printf 'NaN\n'
        return 0
    fi

    delta_uj=$((current_energy - PREV_CPU_ENERGY_UJ))
    delta_s=$((now_ts - PREV_CPU_ENERGY_TS))
    max_uj="$CPU_RAPL_MAX_UJ"

    if (( delta_uj < 0 )) && [[ "$max_uj" =~ ^[0-9]+$ ]] && (( max_uj > 0 )); then
        delta_uj=$((current_energy + max_uj - PREV_CPU_ENERGY_UJ))
    fi

    PREV_CPU_ENERGY_UJ="$current_energy"
    PREV_CPU_ENERGY_TS="$now_ts"

    if (( delta_s <= 0 )) || (( delta_uj < 0 )); then
        printf 'NaN\n'
        return 0
    fi

    awk -v duj="$delta_uj" -v ds="$delta_s" 'BEGIN {
        printf "%.3f", (duj / 1000000.0) / ds
    }'
    printf '\n'
}

print_live_line() {
    local elapsed="$1"
    local cpu_temp="$2"
    local mb_temp="$3"
    local gpu_edge="$4"
    local gpu_power="$5"
    local cpu_power="$6"
    local platform_power="$7"

    local gpu_power_txt cpu_power_txt platform_power_txt
    gpu_power_txt="$gpu_power"
    cpu_power_txt="$cpu_power"
    platform_power_txt="$platform_power"

    if [[ "$gpu_power" != "NaN" ]]; then
        gpu_power_txt="${gpu_power}W"
    fi
    if [[ "$cpu_power" != "NaN" ]]; then
        cpu_power_txt="${cpu_power}W"
    fi
    if [[ "$platform_power" != "NaN" ]]; then
        platform_power_txt="${platform_power}W"
    fi

    printf '[t=%ss] CPU=%sC MB=%sC GPU=%sC GPU_PWR=%s CPU_PWR=%s PWR=%s\n' \
        "$elapsed" "$cpu_temp" "$mb_temp" "$gpu_edge" "$gpu_power_txt" "$cpu_power_txt" "$platform_power_txt" >&2
}

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
setup_cpu_rapl

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

    IFS=',' read -r cpu_temp mb_temp gpu_edge _gpu_junction _gpu_mem gpu_power _cpu_fan _case_fan1 _case_fan2 _gpu_fan <<< "$metrics"
    cpu_power="$(read_cpu_power_rapl)"
    platform_power="$(sum_power_values "$cpu_power" "$gpu_power")"

    printf '%s,%s,%s,%s,%s\n' "$elapsed" "$timestamp" "$metrics" "$cpu_power" "$platform_power" >> "$OUTFILE"

    if [[ "$LIVE_TERMINAL" == "true" ]]; then
        print_live_line "$elapsed" "$cpu_temp" "$mb_temp" "$gpu_edge" "$gpu_power" "$cpu_power" "$platform_power"
    fi

    sleep "$INTERVAL"
done
