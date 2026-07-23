#!/usr/bin/env bash

INTERVAL=1
OUTFILE="${1:-benchmark.csv}"

START=$(date +%s)

echo "time_s,timestamp,cpu_temp_c,mb_temp_c,gpu_edge_c,gpu_junction_c,gpu_mem_c,gpu_power_w,cpu_fan_rpm,case_fan1_rpm,case_fan2_rpm,gpu_fan_rpm" > "$OUTFILE"

while true; do

    NOW=$(date +%s)
    ELAPSED=$((NOW-START))
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    s=$(sensors)

    cpu_temp=$(echo "$s" | awk '
        /Package id 0:/ {
            gsub(/\+|°C/,"",$4)
            print $4
            exit
        }')

    mb_temp=$(echo "$s" | awk '
        /nct6791-isa-0290/ {found=1; next}
        found && /SYSTIN:/ {
            gsub(/\+|°C/,"",$2)
            print $2
            exit
        }')

    gpu_edge=$(echo "$s" | awk '
        /amdgpu-pci-0300/ {found=1; next}
        found && /^edge:/ {
            gsub(/\+|°C/,"",$2)
            print $2
            exit
        }')

    gpu_junction=$(echo "$s" | awk '
        /amdgpu-pci-0300/ {found=1; next}
        found && /^junction:/ {
            gsub(/\+|°C/,"",$2)
            print $2
            exit
        }')

    gpu_mem=$(echo "$s" | awk '
        /amdgpu-pci-0300/ {found=1; next}
        found && /^mem:/ {
            gsub(/\+|°C/,"",$2)
            print $2
            exit
        }')

    gpu_power=$(echo "$s" | awk '
        /amdgpu-pci-0300/ {found=1; next}
        found && /^PPT:/ {
            gsub(/W/,"",$2)
            print $2
            exit
        }')

    cpu_fan=$(echo "$s" | awk '
        /nct6791-isa-0290/ {found=1; next}
        found && /^fan1:/ {
            print $2
            exit
        }')

    case_fan1=$(echo "$s" | awk '
        /nct6791-isa-0290/ {found=1; next}
        found && /^fan2:/ {
            print $2
            exit
        }')

    case_fan2=$(echo "$s" | awk '
        /nct6791-isa-0290/ {found=1; next}
        found && /^fan3:/ {
            print $2
            exit
        }')

    gpu_fan=$(echo "$s" | awk '
        /amdgpu-pci-0300/ {found=1; next}
        found && /^fan1:/ {
            print $2
            exit
        }')


    echo "$ELAPSED,$TIMESTAMP,$cpu_temp,$mb_temp,$gpu_edge,$gpu_junction,$gpu_mem,$gpu_power,$cpu_fan,$case_fan1,$case_fan2,$gpu_fan" >> "$OUTFILE"

    sleep "$INTERVAL"

done
