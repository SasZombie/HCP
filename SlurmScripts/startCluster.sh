#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

set -xeu

TARGET_NAME=$(basename "$1")
MULTIPLE=false

for arg in "$@"; do
  [[ "$arg" == "--multiple" ]] && MULTIPLE=true
done

rm -f "${SCRIPT_DIR}"/*.log "${SCRIPT_DIR}"/*.out || true
rm -rf "${SCRIPT_DIR}"/vtune_results* || true

if [ "$MULTIPLE" = true ]; then
    # Use the absolute SCRIPT_DIR to ensure sbatch finds the file
    sbatch "${SCRIPT_DIR}/${TARGET_NAME}" 0
else
    sbatch "${SCRIPT_DIR}/${TARGET_NAME}" 2
fi