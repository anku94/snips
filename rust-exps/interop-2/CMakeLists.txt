# CMakeLists.txt
cmake_minimum_required(VERSION 3.15)
project(CppRustInterop CXX)

set(CMAKE_CXX_STANDARD 14)

# Include the Rust library's CMake file
add_subdirectory(rust_lib)

# Add the main executable
include_directories(include rust_lib)
add_executable(main src/main.cpp)
target_link_libraries(main rust_lib)
