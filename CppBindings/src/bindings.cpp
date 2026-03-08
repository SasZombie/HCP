#include "HarmonicModule.hpp"
#include <pybind11/pybind11.h>
#include <pybind11/numpy.h>
#include <pybind11/stl.h>

namespace py = pybind11;

PYBIND11_MODULE(PythonHarmonicModule, m)
{
    m.def("analyze_atoms", [](
                               std::vector<double> initial_vec,
                               py::array_t<double> weights,
                               py::array_t<double> coords,
                               size_t lenInfo)
          {
    
        if (initial_vec.size() != 3) {
            throw std::runtime_error("Initial vector must have 3 elements");
        }
    
        Eigen::Vector3d startV{ initial_vec[0], initial_vec[1], initial_vec[2]};

        auto w_ref = weights.unchecked<1>(); 
        auto c_ref = coords.unchecked<2>();

        size_t n_atoms = lenInfo;


        const double* p_weights = weights.data();
        const double* p_coords  = coords.data();

        analyzeAtoms(startV, p_weights, p_coords, n_atoms); });
}