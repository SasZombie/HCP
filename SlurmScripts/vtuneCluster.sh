#!/bin/bash
#SBATCH --partition=haswell
#SBATCH --job-name=vtune_internal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=32G
#SBATCH --time=00:10:00


SCRIPT_DIR="$SLURM_SUBMIT_DIR"

LVL2_DIR=$(dirname "$SCRIPT_DIR")
LVL1_DIR=$(dirname "$LVL2_DIR")

RESULT_DIR="/app/vtune_hpc_result"

apptainer exec \
    --bind "${LVL2_DIR}":/app \
    --pwd /app \
    --cleanenv \
    --env OMP_NUM_THREADS=32 \
    "${LVL1_DIR}/imagineHPC.sif" \
    /bin/bash -c "source /opt/intel/oneapi/vtune/latest/env/vars.sh && \
                  vtune -collect hotspots \
                        -knob sampling-mode=sw \
                        -knob enable-characterization-insights=false \
                        -start-paused \
                        -r $RESULT_DIR \
                        -- /app/venv/bin/python3 ./modular_main.py 1 16"