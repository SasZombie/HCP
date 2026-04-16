#!/bin/bash
#SBATCH --partition=haswell
#SBATCH --job-name=vtune_profiling
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=32G
#SBATCH --output=slurm_job_%j.out
#SBATCH --time=00:40:00

# Configurare Log File
LOG_FILE="profiling_session_$(date +%Y%m%d_%H%M).log"
exec 3>&1 1>>"$LOG_FILE" 2>&1

VTUNE_THREADS=(1 2 8)
TEST_TYPE="3"

echo "======================================================"
echo "      START SESIUNE PROFILARE: $(date)"
echo "======================================================"
echo "Arhitectură detectată: $(lscpu | grep 'Model name' | sed 's/Model name: *//')"
echo "------------------------------------------------------"

for T in "${VTUNE_THREADS[@]}"
do
    echo "[$(date +%H:%M:%S)] Inițiere analiză Hardware pentru T=$T thread-uri..."
    
    RESULTS_DIR="PROFILING_T${T}_$(date +%H%M)"

    apptainer exec --bind /tmp:/tmp ../imagineHPC.sif \
        /bin/bash -c "export LD_PRELOAD=/usr/lib/libstdc++.so.6; /opt/intel/oneapi/vtune/latest/bin64/vtune -collect threading -result-dir $RESULTS_DIR -start-paused ./venv/bin/python3 modular_main.py $TEST_TYPE $T"
    
    if [ $? -eq 0 ]; then
        echo "[$(date +%H:%M:%S)] SUCCES: Raport generat în $RESULTS_DIR"
    else
        echo "[$(date +%H:%M:%S)] EROARE: Profilarea pentru T=$T a eșuat."
    fi
    echo "------------------------------------------------------"
done

echo "======================================================"
echo "      SESIUNE FINALIZATĂ: $(date)"
echo "======================================================"

exec 3>&-