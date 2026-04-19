#/bin/bash

set -xe

rm -rf *.log *.out vtune_results*
sbatch benchmarkCluster.sh