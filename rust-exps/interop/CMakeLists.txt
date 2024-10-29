# CMakeLists.txt
cmake_minimum_required(VERSION 3.15)
project(RustCInterop CXX)

set(CMAKE_CXX_STANDARD 14)

# Locate Rust and build Rust library
find_program(CARGO "cargo")
if(NOT CARGO)
    message(FATAL_ERROR "Cargo (Rust) is required but not found.")
endif()

# Custom target to build Rust library
add_custom_target(rust_lib_build ALL
    COMMAND ${CARGO} build --release
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Building Rust library"
)

if (APPLE)
  set(RUST_LIB_FILE "${CMAKE_CURRENT_SOURCE_DIR}/target/release/librust_lib.dylib")
elseif (UNIX)
  set(RUST_LIB_FILE "${CMAKE_CURRENT_SOURCE_DIR}/target/release/librust_lib.so")
else()
  message(FATAL_ERROR "Unsupported platform")
endif()

add_library(rust_lib STATIC IMPORTED GLOBAL)
set_target_properties(rust_lib PROPERTIES
    IMPORTED_LOCATION "${RUST_LIB_FILE}"
    INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_BINARY_DIR}"
)


# Include the header files
include_directories(include)

# Add the main executable
add_executable(main src/main.cpp)
target_link_libraries(main rust_lib)
