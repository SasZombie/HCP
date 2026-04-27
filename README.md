# Project: Local Structural Order Parameter (LSOP) analysis. 

## Team 
* Hazaparu Sorin-Daniel (2025-2026 AAC)
* Grosu Gabriela-Cătălina (2025-2026 AAC)

## Description
Instead of just counting how many neighbors an atom has, the program calculates the geometric quality of the neighborhood. The code takes the positions of all atoms in a Armstrong difined radius box and calculates:
1. Bond Angles: The precise angle between every neighbor-center-neighbor trio.
2. Symmetry Matching: How closely those angles match ideal mathematical shapes (like a perfect tetrahedron or octahedron).
3. Numerical Scores: A vector of values (0.0 to 1.0) representing the "shape profile" of every single atom.
## Why calculate it  
1. Mapping Disorder and Defects
2. Identifying Phase Transitions(melting point)


## Scenarios
We choose 3 scenarios based on the computation difficulty and resoruces needed:
 * Easy: Silicon, with 25 neighbors and a cutoff value of 4 
 * Hard: Lithium Oxide, with 50 neighbors and a cutoff value of 10
 * Cluster: Hexagonal Lithium Oxide, with 100 neighbors and a cutoff value of 25

# Implementation
To achive the desired outcome we must implement the following steps:
* Data Aquisition from the Material Project API. 
* Scaling up the cell. The default unit cell is to small for any meaningfull statistical analysis.  
* Neighborhood watch. Using a Voronoi tessellation to intelligently decide which atoms are actually "bonded" or coordinated.
* Geometric Fingerprinting. This recognizes the shape of the cell.
* The Bond Valence Analysis.  

The [initial Python-based workflow](naive_main.py "Implementation") proved computationally prohibitive for large-scale simulations. Profiling [data](Results/kprofile.txt "Data") indicates that the primary overhead resides in the calculation of local structural order parameters (80% of total runtime). Specifically, the algorithm suffers from $O(N^3)$ scaling relative to the supercell dimensions and $O(N^2)$ scaling for neighbor-tree queries, leading to inefficient processing as the local environment density increases![Snakeviz Picture](Data/Snakeviz.png)  

Thus the following claims can be made here:
* **Claim A**: Data Parallelism. The profile shows that 98% of execution time (Lines 84 & 87) is spent inside a loop where each iteration is independent. This structure allows for near-linear scaling using MPI or Multiprocessing, as the structure can be decomposed and sites distributed across different cluster nodes with zero inter-node communication required during the calculation phase. According to Amdahl's Law, the maximum speedup we can get is limited by the part of the code that cannot be parallelized, given by: $$Speedup = \frac{1}{s + \frac{1-s}{p}}$$  
Since the serial fraction is just 0.02%, running this on multiple cores the theoretical speedup is massive.
* **Claim B**: Algorithmic Bottleneck. Micro-profiling reveals that get_order_parameters is the primary computational bottleneck (86.1% of runtime). This function performs heavy trigonometric and spherical harmonic calculations in Python. A C++ implementation using a library like Eigen or GSL for the math, exposed via pybind11, would significantly reduce the 'Per Hit' time by eliminating Python's object overhead and utilizing SIMD vectorization.


While the initial [parallel implementation](paralel_main.py "Implementation") in Python (utilizing a worker-pool architecture) yielded significant performance gains—reducing execution time for baseline test cases from minutes to seconds—the scalability limits were reached during high-complexity "Hard" test scenarios. Since the atomic order parameters are independent of one another, the workload is embarrassingly parallel, allowing for a lock-free execution model. However, the inherent overhead of the Python interpreter remained the primary bottleneck.

To address this, the architecture was transitioned to a hybrid C++/Python framework. Rather than refactoring the entire library, a targeted optimization strategy was employed by re-implementing the computationally expensive [get_order_parameters](CppBindings/src/HarmonicModule.cpp "Implementation") function as a C++ extension.

### Key Implementation Details:
* Linear Assignment Optimization: The implementation utilizes the [Hungarian Algorithm](https://github.com/mcximing/hungarian-algorithm-cpp.git "Lib Site") to solve the assignment problem efficiently, reducing the complexity of atomic mapping.

* Linear Algebra Integration: The [Eigen library](https://github.com/PX4/eigen.git "Lib Site") was integrated to handle high-performance matrix operations and coordinate transformations with SIMD optimizations.

* Domain-Specific Constraints: To ensure development efficiency, the implementation was scoped specifically to the geometric shapes relevant to this study, rather than a generalized library for all possible configurations.

This architectural shift leverages the interoperability of C++ for low-level memory management and heavy numerical computation while maintaining the flexibility of Python for high-level data orchestration.

This resulted in a transformative increase in computational throughput. By offloading the function logic to a compiled environment, we achieved near-linear scaling across CPU cores, effectively bypassing the constraints of the GIL.

The specialized implementation reduced the time complexity overhead
associated with high-dimensional atomic configurations.
For the "Hard" test the C++ binding achieved a speedup of several orders of magnitude. This optimization shifts the primary bottleneck from CPU-bound processing to I/O operations, enabling the processing of large-scale molecular trajectories that were previously considered computationally prohibitive.


![SnakevizCpp Picture](Data/SnakeVizParalel.png)

# Findings

| Implementation Strategy | Easy Scenario (Avg.) | Hard Scenario (Avg.) |
| :--- | :---: | :---: |
| **Naive Sequential (Python)** | 3.40 min | > 2.0 hours |
| **Parallel Execution (Python)** | 12.0 sec | > 15.0 min |
| **C++ Binding (Hybrid)** | 5.0 sec | 6.0 min* |
| **Parallel Hybrid (Optimized)** | **< 1.0 sec** | **40.0 sec** |

Note on Bottlenecks: In the Hybrid implementations, the core C++ computation of order parameters required only 0.01s and 0.03s respectively. The remaining execution time is attributed to Python-side data pre-processing and I/O overhead.
# Raports

## Week 1

Sorin:  
* Started by researching the a simple, computationally intensive problem. LSOP is picked and started working on the [naive approach](naive_main.py "Implementation").  
* Materials API is pretty well documented which resulted in a very fast work-flow.
* Started Profiling and analysis of the results.
* Started the [Parallelism implementation](paralel_main.py "Implementation").
* The parallel approach kills all profilers used. 
* Treid using *viztracer*. Eats more than 32 GB ram and kills the machine. Swiched to a max depth of 5. 
* The log is a json of around 1GB. Vs-code cant open it. Swiching to a max depth of 4. Noted a huge reduction in time. From minutes to secconds.
* Sucess! The hard test finishes in 1-2 secconds. The paraleism must be added to pre-processing now.
* Done! The Hard test takes 2 minutes to complete

Gabriela:
* Looking over the Materials site and capabilities.
* Getting an API Key.
* Directing env vars.
* Python libs dont work, swiching to minimal dependencies ones.
* Organised repo and requirements.
* After the hard scenario fails with paraleism, started looking into C++ openmp speed up options.
* Pybind11 is a perfect fit. Reimplementing the whole LSOP is too difficult. Going for a minimialist version in C++.
* Added ompen mp to c++ bindings.

## Week 2

To evaluate the scalability and architectural portability of the algorithm, the deployment was benchmarked across two heterogeneous HPC environments on the UPB cluster. We compared the legacy Intel Haswell-EP architecture (E5-2680 v3), characterized by its monolithic design, against the modern AMD Rome microarchitecture (EPYC 7742), which utilizes a high-bandwidth chiplet design. This selection allows for an analysis of how memory-intensive Voronoi tessellation scales across differing cache hierarchies and memory subsystems.

## Test 1

Running the [benchmaker](benchmarkCluster.sh) on the Haswell cluster  we get the results:


| Threads | Intel (s) | Amd (s) |
| :--- | :--- | :--- |
| 1 | 11.739215913 |12.615934336 |
| 2 | 10.824213070 | 11.250727104 |
| 4 | 10.859506209 | 11.213056265 |
| 8 | 10.826040867 | 11.163926227 |
| 16 | 10.951088817 | 11.278679323 |
| 32 | 11.222310490 | 11.610916813 |

![SpeedUpIntel Picture](Data/SpeedUpIntelTest1.png)
![SpeedUpAmd Picture](Data/SpeedUpAmdTest1.png)
## Conclusions Test 1

### 1. Anomalous Initial Scaling and Parallel Efficiency:  
The transition from 1 to 2 threads yields a speedup factor of approximately $10.13\times$ on the Intel node and $11.24\times$ on the AMD node. In a standard computational model, speedup $S$ is bounded by the number of processors $p$ ($S \le p$); however, these results suggest a cache-resident transition. The single-threaded execution likely suffers from severe cache thrashing or memory latency penalties that are mitigated when the workload is partitioned, allowing the working set to fit within the aggregate L2/L3 cache capacity of multiple cores.
### 2. Scalability Plateaus and Synchronization Overhead  
Beyond $n=2$ threads, both architectures encounter a performance plateau. On the Intel node, a regressive trend is observed at $n=8$ ($6.84s$), likely attributable to NUMA effects or bus contention. The AMD architecture demonstrates superior stability, maintaining a consistent wall time of $\approx 4.4s$. This suggests that the application becomes I/O bound or limited by Amhdahl's Law, where the sequential portion of the algorithm dominates the remaining execution time.
e achieves the lowest absolute wall time at $n=32$ ($4.51s$), the AMD node exhibits a more robust scaling curve with lower variance. The AMD node's ability to maintain performance across high thread counts is indicative of its high-bandwidth Infinity Fabric and larger L3 cache hierarchy, which effectively handles the synchronization overhead that causes the localized performance degradation seen in the Intel results at mid-range threading.

## Test 2:

| Threads | Intel (s) | Amd (s) |
| :--- | :--- | :--- |
| 1 | 521.284142452 | 545.721814129 |
| 2 | 271.254715141 | 309.018799869 |
| 4 | 146.500909343 | 161.561863878 |
| 8 | 85.829464102 | 100.931989351 |
| 16 | 54.721426553 | 67.099733466 |
| 32 | 45.142658563 | 59.543615310 |

![SpeedUpIntel Picture](Data/SpeedUpIntelTest2.png)
![SpeedUpAmd Picture](Data/SpeedUpAmdTest2.png)
## Conclusions Test 2

### 1. Architectural IPC Advantage and Baseline Latency
The AMD architecture demonstrates a consistent ~12% performance lead over the Intel Xeon E5-2680 v3 in single-threaded execution. This delta is representative of the generational leap in IPC and branch prediction efficiency between the Haswell and Rome microarchitectures. For the Hard Test workload, the baseline computational latency is significantly lower on the AMD node, providing a superior foundation for parallel scaling.
### 2. Parallel Efficiency and Scaling Deceleration
Both architectures exhibit a classic sub-linear scaling curve. While the transition from 1 to 4 threads shows strong efficiency ($S \approx 3.6x$), a significant scaling "knee" appears beyond $n=8$ threads.
* Intel Node: Scaling efficiency drops to 31% when moving from 1 to 32 threads ($S = 10.08x$). This degradation is characteristic of Resource Contention, specifically within the Execution Units shared by logical threads on the 24-core Intel node.
* AMD Node: Maintains a slightly higher efficiency at $n=32$ ($S = 11.80x$). The superior performance is attributed to the larger L3 cache hierarchy (256MB on AMD vs 60MB on Intel), which mitigates the memory-access bottlenecks associated with high-concurrency geometric computations.


## Both tests conclusions
### 1. Cache-Resident Transitions  
At $n=1$, the Easy problem size likely exceeds the L1/L2 cache of a single core, leading to massive memory latency. When we move to $n \ge 2$, the workload is partitioned such that the active data fits entirely within the aggregate L3 cache of the allocated cores. Once the problem becomes "cache-resident," additional threads provide zero marginal gain, which is why the time flatlines at $\approx 4.5s$ for both architectures.
### 2. The "Hard" Test: Pure Compute Scaling
In the Hard test, the workload is large enough that it cannot be "hidden" in the cache, forcing a reliance on raw clock speed and memory bandwidth. The AMD EPYC architecture consistently outperforms the Intel Haswell by 11-24%. This is the result of the 5-year generational gap in IPC  and the faster DDR4-3200 memory bus on the AMD nodes.

![Log Scale Amd Picture](Data/LogScaleAmdVsIntelEasyVsHard.png)

# Installation

Our Recomandation is using venv:
```
python3 -m venv venv # or virtualvenv venv (Arch linux)

source venv/bin/activate

pip install -r requirements.txt

cmake --preset release
cmake --build --preset release -j
```
This creates the actual bindings for your target machine. Then you may run modular_main.py.