#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

set -xeu

SCRIPT_TO_RUN=$1
MULTIPLE=false

for arg in "$@"; do
  [[ "$arg" == "--multiple" ]] && MULTIPLE=true
done

rm -f "${SCRIPT_DIR}"/*.log "${SCRIPT_DIR}"/*.out || true
rm -rf "${SCRIPT_DIR}"/vtune_results* || true

if [ "$MULTIPLE" = true ]; then
    sbatch "${SCRIPT_DIR}/$SCRIPT_TO_RUN" 0
else
    sbatch "${SCRIPT_DIR}/$SCRIPT_TO_RUN" 2
fi