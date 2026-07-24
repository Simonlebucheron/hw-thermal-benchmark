#!/usr/bin/env bash

set -u

# Compatibility wrapper retained for existing pwm-based invocations.
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "$script_dir/logger_rpm.sh" "$@"
