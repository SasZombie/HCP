#!/bin/bash

# NOTE: Slurm directives (#SBATCH) MUST come before any executable code 
# like SCRIPT_DIR=... otherwise Slurm might ignore them.

#SBATCH --partition=haswell
#SBATCH --job-name=scaling_test
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=32G               
#SBATCH --output=bench_%j.out   
#SBATCH --time=00:10:00         

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

LVL2_DIR=$(dirname "$SCRIPT_DIR")
LVL1_DIR=$(dirname "$LVL2_DIR")

ME="benchmarkCluster.sh"
ARG=${1:-0}

THREADS=(1 1 2 4 8 16 32)
# Saves log in the root folder
LOG_FILE="${PARENT_DIR}/threadResults_${ARG}.log"
TEST_TYPE="1"

echo "--- Benchmark Start: $(date) ---" > "$LOG_FILE"
echo "Threads | Wall_Time (s) |" >> "$LOG_FILE"
echo "-------------------------" >> "$LOG_FILE"

for T in "${THREADS[@]}"
do
    echo "Running with $T threads..."
    export SLURM_CPUS_PER_TASK=$T
    START=$(date +%s.%N)
    
    apptainer exec \
        --bind "${LVL2_DIR}":/app \
        --pwd /app \
        --cleanenv \
        --env LD_LIBRARY_PATH="/usr/local/lib:/usr/lib/x86_64-linux-gnu" \
        --env OMP_NUM_THREADS=$T \
        "${LVL1_DIR}/imagineHPC.sif" \
        /app/venv/bin/python3 ./modular_main.py $TEST_TYPE $T
    
    END=$(date +%s.%N)
    DIFF=$(echo "$END - $START" | bc)
    echo "$T | $DIFF" >> "$LOG_FILE"
done

echo "--- Benchmark Ended: $(date) ---" >> "$LOG_FILE"

"${SCRIPT_DIR}/multipleBenches.sh" "$ME" "$ARG"