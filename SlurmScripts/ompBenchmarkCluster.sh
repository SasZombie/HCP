#!/bin/bash

#SBATCH --partition=haswell
#SBATCH --job-name=scaling_test
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=32G               
#SBATCH --output=bench_%j.out   
#SBATCH --time=00:05:00         

SCRIPT_DIR="$SLURM_SUBMIT_DIR"
LVL2_DIR=$(dirname "$SCRIPT_DIR")
LVL1_DIR=$(dirname "$LVL2_DIR")

ME="ompBenchmarkCluster.sh"
ARG=${1:-0}

LOG_FILE="${LVL2_DIR}/ompClusterBenchmark.log"

THREADS=(1 2 4 8 16 32)
SCHEDULES=("static" "dynamic" "guided")
BASE_CHUNKS=(1 16 64)

NUM_FACTORS=(2 64 256 4096 16384 65536 262144)



echo "--- Benchmark Start: $(date) ---" > "$LOG_FILE"
echo "Threads | Wall_Time (s) |" >> "$LOG_FILE"
echo "-------------------------" >> "$LOG_FILE"

for SCHED in "${SCHEDULES[@]}"; do
    for T in "${THREADS[@]}"; do

    CURRENT_CHUNKS=("${BASE_CHUNKS[@]}")

    for N in "${NUM_FACTORS[@]}"; do
        NEW_CHUNK=$((6860000 / (T * N) ))
        CURRENT_CHUNKS+=($NEW_CHUNK)
    done


    for CHUNK in "${CHUNKS[@]}"; do
    
            if [ "$CHUNK" -le 0 ]; then CHUNK=1; fi 

            echo "Testing: ${SCHED},${CHUNK} with $T threads" >> "$LOG_FILE"
            
            export OMP_NUM_THREADS=$T
            export OMP_SCHEDULE="${SCHED},${CHUNK}"
            
            apptainer exec \
                --bind "${LVL2_DIR}":/app \
                --pwd /app \
                --cleanenv \
                --env LD_LIBRARY_PATH="/usr/local/lib:/usr/lib/x86_64-linux-gnu" \
                --env OMP_NUM_THREADS=$T \
                --env OMP_SCHEDULE="${SCHED},${CHUNK}" \
                "${LVL1_DIR}/imagineHPC.sif" \
                /app/venv/bin/python3 ./modular_main.py 1 16 
                #Here, python exec time does not matter
                
        done
    done
done

echo "--- Benchmark Ended: $(date) ---" >> "$LOG_FILE"

"${SCRIPT_DIR}/multipleBenches.sh" "$ME" "$ARG"