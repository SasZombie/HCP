#pragma once
#include <vector>
#include <string>
#include <Eigen/Dense>


constexpr size_t TemplateSize = 7;

std::array<double, TemplateSize> analyzeAtoms(const Eigen::Vector3d& center, const double weigts[], const double allCoords[], size_t atoms) noexcept;