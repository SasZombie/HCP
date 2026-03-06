#/bin/bash

rm Results/*

set -xe

python3 -m cProfile -o Results/profile_results.prof -s cumulative naive_main.py > Results/profile_results.txt

kernprof -l -o Results/kprofile.lprof naive_main.py
python3 -m line_profiler -rmt Results/kprofile.lprof >> Results/kprofile.txt