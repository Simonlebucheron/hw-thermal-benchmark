#!/usr/bin/env bash

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

default_tests_for_category() {
    case "$CATEGORY" in
        cpu)
            printf '%s\n' "build-linux-kernel" "compress-zstd"
            ;;
        gpu)
            printf '%s\n' "glmark2" "unigine-heaven"
            ;;
        system)
            printf '%s\n' "build-linux-kernel" "openssl"
            ;;
        *)
            echo "Usage: $0 {cpu|gpu|system}" >&2
            exit 1
            ;;
    esac
}

mapfile -t TESTS < <(
    if [[ -n "$TESTS_CSV" ]]; then
        build_test_list_from_csv "$TESTS_CSV"
    else
        default_tests_for_category
    fi
)

if [[ "${#TESTS[@]}" -eq 0 ]]; then
    echo "No tests resolved. Set openbenchmark.tests in benchmark.config.json." >&2
    exit 1
fi

echo "Running OpenBenchmark category: $CATEGORY"
echo "Tests: ${TESTS[*]}"

export FORCE_TIMES_TO_RUN="${FORCE_TIMES_TO_RUN:-3}"
export SKIP_TESTING_SUBSYSTEMS="${SKIP_TESTING_SUBSYSTEMS:-""}"
exec phoronix-test-suite benchmark "${TESTS[@]}"
