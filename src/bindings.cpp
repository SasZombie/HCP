#include <pybind11/pybind11.h>
#include "HarmonicModule.hpp" 

namespace py = pybind11;

PYBIND11_MODULE(PythonHarmonicModule, m) {
    m.def("analyze_atoms", &analyzeAtoms);
}