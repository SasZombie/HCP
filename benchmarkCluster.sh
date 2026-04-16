#!/bin/bash
#SBATCH --partition=haswell
#SBATCH --job-name=scaling_test
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=32G               
#SBATCH --output=bench_%j.out   
#SBATCH --time=00:05:00         

THREADS=(1 2 4 8 16 32)
LOG_FILE="threadResults.log"
TEST_TYPE="3"

echo "--- Benchmark Start: $(date) ---" > $LOG_FILE
echo "Threads | Wall_Time (s) |" >> $LOG_FILE
echo "-------------------------" >> $LOG_FILE

for T in "${THREADS[@]}"
do
    echo "Running with $T threads..."
    
    export SLURM_CPUS_PER_TASK=$T
    
    START=$(date +%s.%N)
    
    RESULTS_DIR="vtune_results_T${T}"

    apptainer exec ../imagineHPC.sif \
        vtune -collect hotspots \
        -result-dir $RESULTS_DIR \
        ./venv/bin/python3 modular_main.py $TEST_TYPE $T
    
    END=$(date +%s.%N)
    DIFF=$(echo "$END - $START" | bc)
    
    echo "$T | $DIFF" >> $LOG_FILE
    
    echo "Completed $T threads."
done

echo "--- Benchmark Ended: $(date) ---" >> $LOG_FILE