#!/bin/bash
set -xeu

rm -f *.log *.out
rm -rf vtune_results*

sbatch benchmarkCluster.sh