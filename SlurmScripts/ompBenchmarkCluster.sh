#!/bin/bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

#SBATCH --partition=haswell
#SBATCH --job-name=scaling_test
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=32G               
#SBATCH --output=bench_%j.out   
#SBATCH --time=00:05:00         

ME="ompBenchmarkCluster.sh"
ARG=${1:-0}

LOG_FILE="ompClusterBenchmark.log"

THREADS=(1 2 4 8 16 32)
SCHEDULES=("static" "dynamic" "guided")
CHUNKS=(1 16 64)


echo "--- Benchmark Start: $(date) ---" > $LOG_FILE
echo "Threads | Wall_Time (s) |" >> $LOG_FILE
echo "-------------------------" >> $LOG_FILE

for SCHED in "${SCHEDULES[@]}"; do
    for CHUNK in "${CHUNKS[@]}"; do
        for T in "${THREADS[@]}"; do
    
            echo "Testing: ${SCHED},${CHUNK} with $T threads" >> $LOG_FILE
            
            export OMP_NUM_THREADS=$T
            export OMP_SCHEDULE="${SCHED},${CHUNK}"
            

            apptainer exec \
                --bind .:/app \
                --pwd /app \
                --cleanenv \
                --env LD_LIBRARY_PATH="/usr/local/lib:/usr/lib/x86_64-linux-gnu" \
                --env OMP_NUM_THREADS=$T \
                --env OMP_SCHEDULE="${SCHED},${CHUNK}" \
                ../../imagineHPC.sif \
                ./venv/bin/python3 modular_main.py 1 16 
                #Python vars do not matter in this test
                
        done
    done
done

echo "--- Benchmark Ended: $(date) ---" >> $LOG_FILE

./multipleBenches.sh "$ME" "$ARG"