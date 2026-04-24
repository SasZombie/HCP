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


for SCHED in "${SCHEDULES[@]}"; do
    for CHUNK in "${CHUNKS[@]}"; do
        for T in "${THREADS[@]}"; do
    
            echo "Testing: ${SCHED},${CHUNK} with $T threads"
            
            export OMP_NUM_THREADS=$T
            export OMP_SCHEDULE="${SCHED},${CHUNK}"
            
            START=$(date +%s.%N)

            apptainer exec \
                --bind .:/app \
                --env OMP_NUM_THREADS=$T \
                --env OMP_SCHEDULE="${SCHED},${CHUNK}" \
                ../imagineHPC.sif \
                ./venv/bin/python3 modular_main.py $TEST_TYPE $T

            
            END=$(date +%s.%N)
            DIFF=$(echo "$END - $START" | bc)
            
            echo "$T | $DIFF" >> $LOG_FILE
                
        done
    done
done

echo "--- Benchmark Ended: $(date) ---" >> $LOG_FILE
