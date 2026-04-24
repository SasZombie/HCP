#!/bin/bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

#SBATCH --partition=haswell
#SBATCH --job-name=compilation
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8       
#SBATCH --mem=8G                
#SBATCH --output=compile_%j.out   
#SBATCH --time=00:15:00   

NPROCS=${SLURM_CPUS_PER_TASK:-1}

echo "Starting compilation using $NPROCS cores..."

apptainer exec \
    --bind .:/app \
    --pwd /app \
    --cleanenv \
    ../../imagineHPC.sif \
    /bin/bash -c "cd ../CppBindings && \
                  cmake --preset release && \
                  cmake --build --preset release -j $NPROCS"

echo "Compilation finished with exit code $?"