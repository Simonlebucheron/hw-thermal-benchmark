#!/usr/bin/env bash

# Run the configured OpenBenchmark workload for a thermal capture.

set -u -o pipefail

CATEGORY="${1:-cpu}"
TESTS_CSV="${OPENBENCHMARK_TESTS_CSV:-}"

if ! command -v phoronix-test-suite >/dev/null 2>&1; then
    echo "Missing dependency: phoronix-test-suite" >&2
    echo "Install with: sudo apt install phoronix-test-suite" >&2
    exit 1
fi

normalize_test_name() {
    local name="$1"
    name="${name#pts/}"
    printf '%s\n' "$name"
}

build_test_list_from_csv() {
    local csv="$1"
    local -a tests=()
    local item trimmed

    IFS=',' read -r -a raw_items <<<"$csv"
    for item in "${raw_items[@]}"; do
        trimmed="$item"
        trimmed="${trimmed#"${trimmed%%[![:space:]]*}"}"
        trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
        [[ -z "$trimmed" ]] && continue
        tests+=("$(normalize_test_name "$trimmed")")
    done

    printf '%s\n' "${tests[@]}"
}

case "$CATEGORY" in
    cpu|gpu|system)
        ;;
    *)
        echo "Usage: $0 {cpu|gpu|system}" >&2
        exit 1
        ;;
esac

if [[ -z "$TESTS_CSV" ]]; then
    echo "No tests resolved for category '$CATEGORY'. Set openbenchmark.tests in benchmark.config.json or pass OPENBENCHMARK_TESTS_CSV." >&2
    exit 1
fi

mapfile -t TESTS < <(build_test_list_from_csv "$TESTS_CSV")

if [[ "${#TESTS[@]}" -eq 0 ]]; then
    echo "No tests resolved after parsing OPENBENCHMARK_TESTS_CSV." >&2
    exit 1
fi

echo "Running OpenBenchmark category: $CATEGORY"
echo "Tests: ${TESTS[*]}"

export FORCE_TIMES_TO_RUN="${FORCE_TIMES_TO_RUN:-3}"
export SKIP_TESTING_SUBSYSTEMS="${SKIP_TESTING_SUBSYSTEMS:-""}"
exec phoronix-test-suite benchmark "${TESTS[@]}"
