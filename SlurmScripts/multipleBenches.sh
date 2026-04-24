#!/bin/bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

TARGET_SCRIPT=$1
CURRENT_VAL=$2

if [ "$CURRENT_VAL" -lt 2 ]; then
    NEXT_VAL=$((CURRENT_VAL + 1))
    sbatch "$TARGET_SCRIPT" "$NEXT_VAL"
fi