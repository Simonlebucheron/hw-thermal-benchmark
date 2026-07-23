#!/usr/bin/env bash

INTERVAL=1
OUTFILE="${1:-benchmark.csv}"

START=$(date +%s)

echo "time_s,timestamp,cpu_temp_c,mb_temp_c,gpu_edge_c,cpu_fan_pwm_pct,case_fan1_pwm_pct" > "$OUTFILE"

while true; do

    NOW=$(date +%s)
    ELAPSED=$((NOW-START))
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    s=$(sensors)

    cpu=$(echo "$s" | awk '/Package id 0:/ {gsub(/\+|°C/,"",$4); print $4}')

    board=$(echo "$s" | awk '
        /nct6791-isa-0290/ {found=1; next}
        found && /SYSTIN:/ {gsub(/\+|°C/,"",$2); print $2; exit}
    ')

    gpu_edge=$(echo "$s" | awk '
        /amdgpu-pci-0300/ {found=1; next}
        found && /^edge:/ {gsub(/\+|°C/,"",$2); print $2; exit}
    ')

    gpu_junction=$(echo "$s" | awk '
        /amdgpu-pci-0300/ {found=1; next}
        found && /^junction:/ {gsub(/\+|°C/,"",$2); print $2; exit}
    ')

    gpu_mem=$(echo "$s" | awk '
        /amdgpu-pci-0300/ {found=1; next}
        found && /^mem:/ {gsub(/\+|°C/,"",$2); print $2; exit}
    ')

    gpu_power=$(echo "$s" | awk '
        /amdgpu-pci-0300/ {found=1; next}
        found && /^PPT:/ {print $2; exit}
    ')

    cpu_fan=$(echo "$s" | awk '
        /nct6791-isa-0290/ {found=1; next}
        found && /^fan1:/ {print $2; exit}
    ')

    case1=$(echo "$s" | awk '
        /nct6791-isa-0290/ {found=1; next}
        found && /^fan2:/ {print $2; exit}
    ')

    case2=$(echo "$s" | awk '
        /nct6791-isa-0290/ {found=1; next}
        found && /^fan3:/ {print $2; exit}
    ')

    gpu_fan=$(echo "$s" | awk '
        /amdgpu-pci-0300/ {found=1; next}
        found && /^fan1:/ {print $2; exit}
    ')


    echo "$ELAPSED,$TIMESTAMP,$cpu,$board,$gpu_edge,$gpu_junction,$gpu_mem,$gpu_power,$cpu_fan,$case1,$case2,$gpu_fan" >> "$OUTFILE"

    sleep "$INTERVAL"

done
