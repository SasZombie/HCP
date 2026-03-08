#include "HarmonicModule.hpp"

#include <algorithm>
#include <numeric>
#include <iostream>

enum struct AtomShapeType
{
    TET,
    OCT,
    BCC,
    SQ_PYR,
    COUNT
};

static constexpr double tetTemplate[] = {
    0.57735f, 0.57735f, 0.57735f,
    0.57735f, -0.57735f, -0.57735f,
    -0.57735f, 0.57735f, -0.57735f,
    -0.57735f, -0.57735f, 0.57735f};

static constexpr double octTemplate[] = {
    0.57735f,
    0.f,
    0.f,
    -0.57735f,
    0.f,
    0.f,
    0.f,
    0.57735f,
    0.0,
    0.f,
    -0.57735f,
    0.f,
    0.f,
    0.f,
    0.57735f,
    0.f,
    0.f,
    -0.57735f,
};

static constexpr double bccTemplate[] = {
    0.57735f, 0.57735f, 0.57735f,
    0.57735f, 0.57735f, -0.57735f,
    0.57735f, -0.57735f, 0.57735f,
    0.57735f, -0.57735f, -0.57735f,
    -0.57735f, 0.57735f, 0.57735f,
    -0.57735f, 0.57735f, -0.57735f,
    -0.57735f, -0.57735f, 0.57735f,
    -0.57735f, -0.57735f, -0.57735f};

static constexpr double sqPyrTemplate[] = {
    0.57735f, 0.f, 0.f,
    -0.57735f, 0.f, 0.f,
    0.f, 0.57735f, 0.f,
    0.f, -0.57735f, 0.f,
    0.f, 0.f, 0.57735f};

struct AtomTemplate
{
    const double *data;
    const size_t size;
};

static constexpr AtomTemplate LOOKUP[] = {
    {tetTemplate, 12},
    {octTemplate, 18},
    {bccTemplate, 24},
    {sqPyrTemplate, 15}

};

double alignScore(const Eigen::Matrix<double, 24, 3, Eigen::RowMajor> &elems, const AtomTemplate &temp) noexcept
{
    return 1;
}

void analyzeAtoms(const Eigen::Vector3d &center, const double weights[], const double allCoords[], size_t numAtoms) noexcept
{
    std::vector<size_t> indices(numAtoms);
    std::iota(indices.begin(), indices.end(), 0);

    constexpr size_t maxAtomsNeeded = 8;
    size_t k = std::min(numAtoms, maxAtomsNeeded);

    std::partial_sort(indices.begin(), indices.begin() + k, indices.end(),
                      [&](size_t i, size_t j)
                      { return weights[i] > weights[j]; });

    double result[4];
    Eigen::Matrix<double, 8, 3, Eigen::RowMajor> vecs;

    for (int i = 0; i < static_cast<int>(AtomShapeType::COUNT); ++i)
    {
        const AtomTemplate &lookup = LOOKUP[i];
        size_t needed = lookup.size / 3;

        if (numAtoms < needed)
        {
            result[i] = 0;
            continue;
        }

        for (size_t j = 0; j < needed; ++j)
        {
            size_t idx = indices[j] * 3;

            Eigen::Map<const Eigen::Vector3d, Eigen::Unaligned> neighbor(&allCoords[idx]);

            Eigen::Vector3d normalized = (neighbor - center);
            double n = normalized.norm();
            vecs.row(j) = normalized / (n + 1e-12);
        }

        std::cout << "--- Template: " << " (" << needed << " neighbors) ---" << std::endl;
        std::cout << vecs.topRows(needed) << std::endl;
        result[i] = alignScore(vecs.topRows(needed), lookup);
    }
}