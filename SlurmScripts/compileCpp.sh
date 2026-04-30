#!/bin/bash

#SBATCH --partition=haswell
#SBATCH --job-name=compilation
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8       
#SBATCH --mem=8G                
#SBATCH --output=compile_%j.out   
#SBATCH --time=00:15:00   

SCRIPT_DIR="$SLURM_SUBMIT_DIR"

LVL2_DIR=$(dirname "$SCRIPT_DIR")
LVL1_DIR=$(dirname "$LVL2_DIR")

NPROCS=${SLURM_CPUS_PER_TASK:-1}

apptainer exec \
    --bind "${LVL2_DIR}":/app \
    --pwd /app \
    --cleanenv \
    "${LVL1_DIR}/imagineHPC.sif" \
    /bin/bash -c "cd /app/CppBindings && \
                source /opt/intel/oneapi/vtune/latest/env/vars.sh && \
                cmake --preset release && \
                cmake --build --preset release -j $NPROCS"

echo "Compilation finished with exit code $?"