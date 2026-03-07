#/bin/bash

if [ ! -d "Results" ]; then
  mkdir "Results"
fi

SCRIPT_TESTED="$1"

SCRIPT_PATH="Results/profile_results_${SCRIPT_TESTED}"
KPROFILE_PATH="Results/kprofile_${SCRIPT_TESTED}"

rm Results/*

set -xe

python3 -m cProfile -o $SCRIPT_PATH.prof -s cumulative $SCRIPT_TESTED.py >> $SCRIPT_PATH.txt

kernprof -l -o $KPROFILE_PATH.lprof $SCRIPT_TESTED.py
python3 -m line_profiler -rmt $KPROFILE_PATH.lprof >> $KPROFILE_PATH.txt