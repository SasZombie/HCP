#!/bin/bash
set -xeu

# Usage: ./start.sh benchmarkCluster.sh --multiple
SCRIPT_TO_RUN=$1
MULTIPLE=false

for arg in "$@"; do
  [[ "$arg" == "--multiple" ]] && MULTIPLE=true
done

rm -f *.log *.out || true
rm -rf vtune_results* || true

if [ "$MULTIPLE" = true ]; then
    sbatch "$SCRIPT_TO_RUN" 0
else
    sbatch "$SCRIPT_TO_RUN" 2
fi