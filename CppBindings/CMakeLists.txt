cmake_minimum_required(VERSION 3.14)
project(CppBindings LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(project_warnings INTERFACE)
target_compile_options(project_warnings INTERFACE
    $<$<CONFIG:Debug>:-Wall -Wextra -Wformat-nonliteral -Wcast-align -Wpointer-arith
    -Wmissing-declarations -Winline -Wundef -Wcast-qual -Wshadow
    -Wwrite-strings -Wno-unused-parameter -Wfloat-equal -g -ggdb -O2>

    $<$<CONFIG:Release>:-O3 -g>
)

include(FetchContent)

fetchcontent_declare(pybind11
    GIT_REPOSITORY https://github.com/pybind/pybind11.git
    GIT_TAG v2.13.1)
fetchcontent_makeavailable(pybind11)

fetchcontent_declare(
    eigen
    GIT_REPOSITORY https://gitlab.com/libeigen/eigen.git
    GIT_TAG 3.4.0
)
fetchcontent_makeavailable(eigen)

find_path(VALGRIND_INCLUDE_DIR NAMES valgrind/callgrind.h)

set(VTUNE_DIR $ENV{VTUNE_PROFILER_DIR})

if(NOT VTUNE_DIR)
    message(WARNING "VTUNE_PROFILER_DIR not found. Profiling hooks might fail to compile.")
else()
    set(ITT_INCLUDE_DIR "${VTUNE_DIR}/include")
    find_library(ITT_LIB NAMES ittnotify PATHS "${VTUNE_DIR}/lib64")
endif()

add_library(HarmonicModule src/HarmonicModule.cpp src/Hungarian.cpp)

target_include_directories(HarmonicModule PUBLIC include)
target_link_libraries(HarmonicModule
    PUBLIC Eigen3::Eigen
    PRIVATE project_warnings)


set_target_properties(HarmonicModule PROPERTIES POSITION_INDEPENDENT_CODE ON)

pybind11_add_module(PythonHarmonicModule src/bindings.cpp)

target_include_directories(PythonHarmonicModule PRIVATE
    ${VALGRIND_INCLUDE_DIR}
    ${ITT_INCLUDE_DIR}
)

target_link_libraries(PythonHarmonicModule PRIVATE
    HarmonicModule
    ${ITT_LIB}
    ${CMAKE_DL_LIBS})
set_target_properties(PythonHarmonicModule PROPERTIES PREFIX "")

