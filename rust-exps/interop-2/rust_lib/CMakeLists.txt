# rust_lib/CMakeLists.txt
cmake_minimum_required(VERSION 3.15)
project(rust_lib)

# Locate Cargo
find_program(CARGO "cargo" REQUIRED)
find_program(CBINDGEN "cbindgen" REQUIRED)

# Generate C bindings using cbindgen
add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/point.h
    COMMAND ${CBINDGEN} --config ${CMAKE_CURRENT_SOURCE_DIR}/cbindgen.toml --crate rust_lib --output ${CMAKE_CURRENT_BINARY_DIR}/point.h
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/src/lib.rs
    COMMENT "Generating C bindings with cbindgen"
)

# Custom target to build the Rust library
add_custom_target(rust_lib_build ALL
    COMMAND ${CARGO} build --release
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Building Rust library"
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/point.h
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

# Ensure Rust library build before usage
add_dependencies(rust_lib rust_lib_build)
