#!/bin/bash
ARG=$1

if [ "$ARG" -lt 3 ]; then
    NEXT_ARG=$((ARG + 1))
    sbatch benchmarkCluster.sh "$NEXT_ARG"
fi