#!/usr/bin/env bash

set -u -o pipefail

SCENARIO="${1:-cpu}"

if ! command -v phoronix-test-suite >/dev/null 2>&1; then
    echo "Missing dependency: phoronix-test-suite" >&2
    echo "Install with: sudo apt install phoronix-test-suite" >&2
    exit 1
fi

case "$SCENARIO" in
    cpu)
        TESTS=(pts/compress-zstd pts/build-linux-kernel)
        ;;
    gpu)
        TESTS=(pts/unigine-heaven pts/glmark2)
        ;;
    mixed)
        TESTS=(pts/build-linux-kernel pts/glmark2)
        ;;
    *)
        echo "Usage: $0 {cpu|gpu|mixed}" >&2
        exit 1
        ;;
esac

echo "Running OpenBenchmark scenario: $SCENARIO"
echo "Tests: ${TESTS[*]}"

# Batch mode avoids interactive prompts to keep runs reproducible.
export FORCE_TIMES_TO_RUN="${FORCE_TIMES_TO_RUN:-3}"
export SKIP_TESTING_SUBSYSTEMS="${SKIP_TESTING_SUBSYSTEMS:-""}"
exec phoronix-test-suite batch-run "${TESTS[@]}"
