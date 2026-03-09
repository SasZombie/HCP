#pragma once
#include <vector>
#include <string>
#include <Eigen/Dense>


std::array<double, 4> analyzeAtoms(const Eigen::Vector3d& center, const double weigts[], const double allCoords[], size_t atoms) noexcept;