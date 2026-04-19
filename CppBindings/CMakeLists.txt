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

find_package(OpenMP REQUIRED)

include(FetchContent)

fetchcontent_declare(pybind11
    GIT_REPOSITORY https://github.com/pybind/pybind11.git
    GIT_TAG v2.13.1)
fetchcontent_makeavailable(pybind11)

fetchcontent_declare(eigen
    GIT_REPOSITORY https://gitlab.com/libeigen/eigen.git
    GIT_TAG 3.4.0)
fetchcontent_makeavailable(eigen)

add_library(HarmonicModule src/HarmonicModule.cpp src/Hungarian.cpp)
target_include_directories(HarmonicModule PUBLIC include)
target_link_libraries(HarmonicModule
    PUBLIC
    Eigen3::Eigen
    OpenMP::OpenMP_CXX
    PRIVATE
    project_warnings)

set_target_properties(HarmonicModule PROPERTIES POSITION_INDEPENDENT_CODE ON)

pybind11_add_module(PythonHarmonicModule src/bindings.cpp)
target_link_libraries(PythonHarmonicModule PRIVATE HarmonicModule ${CMAKE_DL_LIBS})
set_target_properties(PythonHarmonicModule PROPERTIES PREFIX "")

# Valgrind
find_path(VALGRIND_INCLUDE_DIR NAMES valgrind/callgrind.h)
if(VALGRIND_INCLUDE_DIR)
    message(STATUS "Found Valgrind: ${VALGRIND_INCLUDE_DIR}")
    target_include_directories(PythonHarmonicModule PRIVATE ${VALGRIND_INCLUDE_DIR})
    target_compile_definitions(PythonHarmonicModule PRIVATE HAVE_VALGRIND)
else()
    message(STATUS "Valgrind NOT found. Callgrind hooks will be disabled.")
endif()

# Intel VTune 
set(VTUNE_DIR $ENV{VTUNE_PROFILER_DIR})
if(VTUNE_DIR)
    find_path(ITT_INCLUDE_DIR NAMES ittnotify.h PATHS "${VTUNE_DIR}/include")
    find_library(ITT_LIB NAMES ittnotify PATHS "${VTUNE_DIR}/lib64")

    if(ITT_INCLUDE_DIR AND ITT_LIB)
        message(STATUS "Found VTune ITT API.")
        target_include_directories(PythonHarmonicModule PRIVATE ${ITT_INCLUDE_DIR})
        target_link_libraries(PythonHarmonicModule PRIVATE ${ITT_LIB})
        target_compile_definitions(PythonHarmonicModule PRIVATE HAVE_VTUNE)
    endif()
else()
    message(STATUS "VTUNE_PROFILER_DIR not set. VTune hooks will be disabled.")
endif()
