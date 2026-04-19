#include "HarmonicModule.hpp"
#include <pybind11/pybind11.h>
#include <pybind11/numpy.h>
#include <pybind11/eigen.h>
#include <pybind11/stl.h>

// #ifdef HAVE_VALGRIND
// #include <valgrind/callgrind.h>
// #endif

// #ifdef HAVE_VTUNE
// #include <ittnotify.h>
// #endif

#include <omp.h>

namespace py = pybind11;

PYBIND11_MODULE(PythonHarmonicModule, m)
{
    m.def("analyze_atoms", [](py::array_t<double> centers,
                              py::list weights_list,
                              py::list coords_list,
                              size_t n_structures)
          {
            auto centers_ref = centers.unchecked<2>();
            Eigen::Matrix<double, Eigen::Dynamic, 4, Eigen::RowMajor> all_results(n_structures, 4);

            struct Task
            {
                const double* w;
                const double* c;
                size_t n_atoms; 
            };

            std::vector<Task> tasks(n_structures);

            for(size_t i = 0; i < n_structures; ++i)
            {
                auto w_arr = weights_list[i].cast<py::array_t<double>>();
                auto c_arr = coords_list[i].cast<py::array_t<double>>();
                tasks[i] = { w_arr.data(), c_arr.data(), static_cast<size_t>(w_arr.size()) };
            }


            {
            
            py::gil_scoped_release release;

// #ifdef HAVE_VALGRIND
//                 CALLGRIND_START_INSTRUMENTATION;
// #endif

// #ifdef HAVE_VTUNE
//                 __itt_resume();
// #endif
#pragma omp parallel for schedule(guided)
                for (int i = 0; i < static_cast<int>(n_structures); ++i)
                {
                    Eigen::Vector3d c{centers_ref(i, 0), centers_ref(i, 1), centers_ref(i, 2)};
                    
                    std::array<double, 4> scores = analyzeAtoms(c, tasks[i].w, tasks[i].c, tasks[i].n_atoms);

                    for(int j = 0; j < 4; ++j) 
                    {
                        all_results(i, j) = scores[j];
                    }
                }

// #ifdef HAVE_VALGRIND
//                 CALLGRIND_STOP_INSTRUMENTATION;
// #endif

// #ifdef HAVE_VTUNE
//                 __itt_pause();
// #endif
            }

            return all_results; });
}