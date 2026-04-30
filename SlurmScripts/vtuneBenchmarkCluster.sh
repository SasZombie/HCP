#!/bin/bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
#SBATCH --partition=haswell
#SBATCH --job-name=vtune_profiling
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=32G
#SBATCH --output=slurm_job_%j.out
#SBATCH --time=00:05:00

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

    # apptainer exec --bind /tmp:/tmp ../imagineHPC.sif \
    #     /bin/bash -c "export LD_PRELOAD=/usr/lib/libstdc++.so.6; \
    #     /opt/intel/oneapi/vtune/latest/bin64/vtune -collect hotspots \
    #     -knob sampling-mode=sw \
    #     -knob stack-size=0 \
    #     -result-dir $RESULTS_DIR \
    #     -- ./venv/bin/python3 modular_main.py $TEST_TYPE $T"

    # apptainer exec --bind /tmp:/tmp ../imagineHPC.sif \
    #     /bin/bash -c "export LD_PRELOAD=/usr/lib/libstdc++.so.6; \
    #     vtune -collect memory-access \
    #     -knob sampling-mode=sw \
    #     -result-dir $RESULTS_DIR \
    #     -start-paused \
    #     -- ./venv/bin/python3 modular_main.py $TEST_TYPE $T"

    # sudo sysctl -w kernel.perf_event_paranoid=1
    # sudo sysctl -w kernel.nmi_watchdog=0

    # vtune -collect hotspots \
    #   -start-paused \
    #   -knob sampling-mode=hw \
    #   -mrte-mode=native \
    #   -result-dir vtune_intel_results \
    #   -- python3 modular_main.py


    # vtune -report hotspots \
    # -result-dir vtune_intel_results \
    # -group-by module,function

    # advixe-cl -collect survey \
    #       -start-paused \
    #       -project-dir ./roofline_report \
    #       -- python3 modular_main.py

    # advixe-cl -collect tripcounts -flop \
    #     -start-paused \
    #     -project-dir ./roofline_report \
    #     -- python3 modular_main.py


    # advixe-cl -report roofline \
    #     -project-dir ./roofline_report \
    #     -report-output ./harmonic_roofline.html
        
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