cmake_minimum_required(VERSION 3.14)
project(CppBindings LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(project_warnings INTERFACE)
target_compile_options(project_warnings INTERFACE
    $<$<CONFIG:Debug>:-Wall -Wextra -Wformat-nonliteral -Wcast-align -Wpointer-arith
    -Wmissing-declarations -Winline -Wundef -Wcast-qual -Wshadow
    -Wwrite-strings -Wno-unused-parameter -Wfloat-equal>
    
    $<$<CONFIG:Release>:-O3>
)

add_library(project_sanitizers INTERFACE)
target_compile_options(project_sanitizers INTERFACE
    $<$<CONFIG:Debug>:-fsanitize=undefined -fsanitize=address -fsanitize=leak -g>
)
target_link_options(project_sanitizers INTERFACE
    $<$<CONFIG:Debug>:-fsanitize=undefined -fsanitize=address -fsanitize=leak>
)

include(FetchContent)

FetchContent_Declare(googletest
    URL https://github.com/google/googletest/archive/refs/heads/main.zip
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE)
FetchContent_MakeAvailable(googletest)

FetchContent_Declare(pybind11
    GIT_REPOSITORY https://github.com/pybind/pybind11.git
    GIT_TAG v2.13.1)
FetchContent_MakeAvailable(pybind11)

add_library(HarmonicModule src/HarmonicModule.cpp)
target_include_directories(HarmonicModule PUBLIC include)
target_link_libraries(HarmonicModule PRIVATE project_warnings project_sanitizers)

set_target_properties(HarmonicModule PROPERTIES POSITION_INDEPENDENT_CODE ON)

pybind11_add_module(PythonHarmonicModule src/bindings.cpp)
target_link_libraries(PythonHarmonicModule PRIVATE HarmonicModule)
set_target_properties(PythonHarmonicModule PROPERTIES PREFIX "")

add_executable(main src/main.cpp)
target_link_libraries(main PRIVATE HarmonicModule project_warnings project_sanitizers)

# add_executable(Tests tests/harmonic_tests.cpp)
# target_link_libraries(Tests PRIVATE
#     HarmonicModule
#     GTest::gtest_main
#     project_warnings
#     project_sanitizers
# )
