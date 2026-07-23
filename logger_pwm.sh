#!/usr/bin/env bash

set -u

# Legacy entrypoint retained for compatibility.
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "$script_dir/logger_rpm.sh" "$@"
