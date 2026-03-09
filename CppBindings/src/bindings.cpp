#include "HarmonicModule.hpp"
#include <pybind11/pybind11.h>
#include <pybind11/numpy.h>
#include <pybind11/eigen.h>
#include <pybind11/stl.h>

namespace py = pybind11;

PYBIND11_MODULE(PythonHarmonicModule, m)
{
    m.def("analyze_atoms", [](py::array_t<double> centers,
                              py::object weights_list,
                              py::object coords_list,
                              size_t n_structures)
          {
    
            auto centers_ref = centers.unchecked<2>();
            
            Eigen::Matrix<double, Eigen::Dynamic, 4, Eigen::RowMajor> all_results(n_structures, 4);

            for (size_t i = 0; i < n_structures; ++i) {
            
            Eigen::Vector3d current_center{centers_ref(i, 0), centers_ref(i, 1), centers_ref(i, 2)};

            // Get the weights and coords arrays from the Python lists
            auto w_arr = weights_list.attr("__getitem__")(i).cast<py::array_t<double>>();
            auto c_arr = coords_list.attr("__getitem__")(i).cast<py::array_t<double>>();

            size_t num_neighbors = w_arr.size();

            std::array<double, 4> scores = analyzeAtoms(current_center, w_arr.data(), c_arr.data(), num_neighbors);

            for(int j = 0; j < 4; ++j) {
                all_results(i, j) = scores[j];
            }
        }

        return all_results; });
}