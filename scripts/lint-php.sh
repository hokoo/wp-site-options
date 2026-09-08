#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

mapfile -d '' php_files < <(
    find plugin-dir tests -type f -name '*.php' -print0 | sort -z
)

if (( ${#php_files[@]} == 0 )); then
    echo 'No PHP files found to lint.' >&2
    exit 1
fi

for php_file in "${php_files[@]}"; do
    php -l "$php_file"
done
