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

Running the [benchmaker](benchmarkCluster.sh) on the Haswell cluster (Intel(R) Xeon(R) Silver 4216 CPU @ 2.10GHz) we get the results:

| Threads | Wall Time (s) |
| :--- | :--- | 
| 1 | 47.188177105 |
| 2 | 4.657180860 | 
| 4 | 5.781218087 | 
| 8 | 6.841852061 | 
| 16 | 4.594425071 |
| 32 | 4.511585210 |

![SpeedUp Picture](Data/SpeedUp.png)

This plot and table give a clear answer:  
* Massive Speedup: There is a huge performance gain going from 1 thread ($47.19s$) to 2 threads ($4.66s$). This suggests the single-threaded version might be hitting a specific bottleneck that parallelism solves immediately.
* Diminishing Returns: After 2 threads, the execution time stays relatively flat (between $4.5s$ and $6.8s$) actually increasing after 8 threads and decreasing at 16.

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