#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

RUN_PLUGIN_CHECK=1 exec "${script_dir}/test-integration.sh" latest
