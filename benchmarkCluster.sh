#!/bin/bash
#SBATCH --job-name=scaling_test
#SBATCH --partition=calcul
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=32G               
#SBATCH --output=bench_%j.out   
#SBATCH --time=00:40:00         

THREADS=(1 2 4 8 16 32)
LOG_FILE="threadResults.log"
TEST_TYPE="3"

echo "--- Benchmark Start: $(date) ---" > $LOG_FILE
echo "Threads | Wall_Time (s) | Max_RSS (KB)" >> $LOG_FILE
echo "--------------------------------------" >> $LOG_FILE

for T in "${THREADS[@]}"
do
    echo "Running with $T threads..."
    
    export SLURM_CPUS_PER_TASK=$T
    
    /usr/bin/time -f "$T | %e | %M" -a -o $LOG_FILE \
    apptainer exec ../imagineHPC.sif ./venv/bin/python3 modular_main.py $TEST_TYPE $T
    
    echo "Completed $T threads."
done

echo "--- Benchmark Ended: $(date) ---" >> $LOG_FILE