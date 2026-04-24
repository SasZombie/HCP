#!/bin/bash

#SBATCH --partition=haswell
#SBATCH --job-name=scaling_test
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=32G               
#SBATCH --output=bench_%j.out   
#SBATCH --time=00:10:00         

ARG=$1

THREADS=(1 1 2 4 8 16 32)
LOG_FILE="threadResults_${ARG}.log"
TEST_TYPE="1"

echo "--- Benchmark Start: $(date) ---" > $LOG_FILE
echo "Threads | Wall_Time (s) |" >> $LOG_FILE
echo "-------------------------" >> $LOG_FILE

for T in "${THREADS[@]}"
do
    echo "Running with $T threads..."
    
    export SLURM_CPUS_PER_TASK=$T
    
    START=$(date +%s.%N)

    apptainer exec \
        --bind .:/app \
        --pwd /app \
        --cleanenv \
        --env LD_LIBRARY_PATH="/usr/local/lib:/usr/lib/x86_64-linux-gnu" \
        --env OMP_NUM_THREADS=$T \
        ../imagineHPC.sif \
        ./venv/bin/python3 modular_main.py $TEST_TYPE $T
    
    END=$(date +%s.%N)
    DIFF=$(echo "$END - $START" | bc)
    
    echo "$T | $DIFF" >> $LOG_FILE
    
    echo "Completed $T threads."
done

echo "--- Benchmark Ended: $(date) ---" >> $LOG_FILE

./multipleBenches.sh "$ARG"