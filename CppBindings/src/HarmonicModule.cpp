#include "HarmonicModule.hpp"
#include "Hungarian.h"

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
static_assert(sizeof(LOOKUP) / sizeof(AtomTemplate) == static_cast<long>(AtomShapeType::COUNT));

// Kabsch and Hungarian Algorithms
double alignScore(const Eigen::Matrix<double, 24, 3, Eigen::RowMajor> &elems, const AtomTemplate &temp) noexcept
{
    const size_t n = temp.size / 3;
    Eigen::Map<const Eigen::Matrix<double, Eigen::Dynamic, 3, Eigen::RowMajor>, Eigen::Unaligned>
        templateMat(temp.data, n, 3);

    Eigen::Matrix3d hMatrix = elems.topRows(n).transpose() * templateMat;

    Eigen::JacobiSVD<Eigen::Matrix3d> svd(hMatrix, Eigen::ComputeFullU | Eigen::ComputeFullV);
    Eigen::Matrix3d U = svd.matrixU();
    Eigen::Vector3d S = svd.singularValues();
    Eigen::Matrix3d V = svd.matrixV();

    Eigen::Matrix3d rotationMatrix = V * U.transpose();

    if (rotationMatrix.determinant() < 0)
    {
        Eigen::Matrix3d flip = Eigen::Matrix3d::Identity();
        flip(2, 2) = -1.0;
        rotationMatrix = V * flip * U.transpose();
    }

    Eigen::Matrix<double, Eigen::Dynamic, 3> actualRotated = elems.topRows(n) * rotationMatrix.transpose();

    Eigen::MatrixXd distMatrix(n, n);

    for (size_t r = 0; r < n; ++r)
    {
        for (size_t c = 0; c < n; ++c)
        {
            distMatrix(r, c) = (actualRotated.row(r) - templateMat.row(c)).squaredNorm();
        }
    }

    // This is slow
    std::vector<std::vector<double>> costMatrix(n, std::vector<double>(n));

    for (size_t i = 0; i < n; ++i)
    {
        for (size_t j = 0; j < n; ++j)
        {
            costMatrix[i][j] = distMatrix(i, j);
        }
    }
    HungarianAlgorithm hungarian;
    std::vector<int> assignment;
    double totalCost = hungarian.Solve(costMatrix, assignment);

    double rmsd = std::sqrt(totalCost / static_cast<double>(n));

    return max(0.0, 1.0 - rmsd);
}

std::array<double, 4> analyzeAtoms(const Eigen::Vector3d &center, const double weights[], const double allCoords[], size_t numAtoms) noexcept
{
    std::vector<size_t> indices(numAtoms);
    std::iota(indices.begin(), indices.end(), 0);

    constexpr size_t maxAtomsNeeded = 8;
    size_t k = std::min(numAtoms, maxAtomsNeeded);

    std::partial_sort(indices.begin(), indices.begin() + k, indices.end(),
                      [&](size_t i, size_t j)
                      { return weights[i] > weights[j]; });

    std::array<double, 4> result;
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

        result[i] = alignScore(vecs.topRows(needed), lookup);
    }

    return result;
}