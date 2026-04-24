#!/bin/bash

# Get the absolute path of the SlurmScripts folder
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

set -xeu

# Strip any leading path from the argument (e.g., ./SlurmScripts/script.sh becomes script.sh)
TARGET_NAME=$(basename "$1")
MULTIPLE=false

for arg in "$@"; do
  [[ "$arg" == "--multiple" ]] && MULTIPLE=true
done

# Cleanup specifically in the SlurmScripts folder
rm -f "${SCRIPT_DIR}"/*.log "${SCRIPT_DIR}"/*.out || true
rm -rf "${SCRIPT_DIR}"/vtune_results* || true

if [ "$MULTIPLE" = true ]; then
    # Use the absolute SCRIPT_DIR to ensure sbatch finds the file
    sbatch "${SCRIPT_DIR}/${TARGET_NAME}" 0
else
    sbatch "${SCRIPT_DIR}/${TARGET_NAME}" 2
fi