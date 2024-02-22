cmake_minimum_required(VERSION 3.10)
project(fi_bench)

# Set the C++ standard to use
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find the required packages
find_package(Libfabric REQUIRED)

# Include directories for libfabric
include_directories(${LIBFABRIC_INCLUDE_DIRS})

# Define the executable for the client
add_executable(client client_main.cpp fabric.cpp endpoint.cpp benchmark.cpp)
# Link the client executable with libfabric
target_link_libraries(client ${LIBFABRIC_LIBRARIES})

# Define the executable for the server
add_executable(server server_main.cpp fabric.cpp endpoint.cpp benchmark.cpp)
# Link the server executable with libfabric
target_link_libraries(server ${LIBFABRIC_LIBRARIES})
