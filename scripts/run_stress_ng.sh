#!/usr/bin/env bash

set -u -o pipefail

DURATION="${1:-900}"
CPU_WORKERS="${CPU_WORKERS:-0}"
GPU_WORKERS="${GPU_WORKERS:-1}"

if ! command -v stress-ng >/dev/null 2>&1; then
    echo "Missing dependency: stress-ng" >&2
    echo "Install with: sudo apt install stress-ng" >&2
    exit 1
fi

if ! [[ "$DURATION" =~ ^[0-9]+$ ]]; then
    echo "Usage: $0 <duration_seconds>" >&2
    exit 1
fi

echo "Running stress-ng for ${DURATION}s (CPU workers: ${CPU_WORKERS}, GPU workers: ${GPU_WORKERS})"
exec stress-ng \
    --cpu "$CPU_WORKERS" \
    --cpu-method matrixprod \
    --gpu "$GPU_WORKERS" \
    --gpu-method all \
    --tz \
    --timeout "${DURATION}s" \
    --metrics-brief
