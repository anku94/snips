cmake_minimum_required(VERSION 3.10)
project(fi_bench)

find_package(PkgConfig)
# Set the C++ standard to use
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON CACHE INTERNAL "")

set(DEPENDENCIES "")
list(APPEND DEPENDENCIES "LIBFABRIC|libfabric")
list(APPEND DEPENDENCIES "LIBIBVERBS|libibverbs>=1.10")

set(src_common
  common.cc
  server.cpp
  client.cpp
  )

# Define the executable for the client
add_executable(client client_main.cpp ${src_common})
add_executable(server server_main.cpp ${src_common})

foreach(DEP IN LISTS DEPENDENCIES)
  message(STATUS "DEP: ${DEP}")
  string(REPLACE "|" " " DEP_LIST ${DEP})
  separate_arguments(DEP_LIST)
  list(GET DEP_LIST 0 DEP_NAME)
  list(GET DEP_LIST 1 PKG_NAME)
  message(STATUS "DEP_NAME: ${DEP_NAME}, PKG_NAME: ${PKG_NAME}")

  # Check for the package
  pkg_check_modules(${DEP_NAME} REQUIRED IMPORTED_TARGET GLOBAL ${PKG_NAME})

  # Check if the package is found and display the relevant information
  if(${DEP_NAME}_FOUND)
    message(STATUS "${PKG_NAME} found")
    message(STATUS "${DEP_NAME}_INCLUDE_DIRS: ${${DEP_NAME}_INCLUDE_DIRS}")
    message(STATUS "${DEP_NAME}_LIBRARY_DIRS: ${${DEP_NAME}_LIBRARY_DIRS}")
    # message(STATUS "${DEP_NAME}_LIBRARIES: ${${DEP_NAME}_LIBRARIES}")
  else()
    message(FATAL_ERROR "${PKG_NAME} not found")
  endif()

  target_link_libraries(client PRIVATE PkgConfig::${DEP_NAME})
  target_link_libraries(server PUBLIC PkgConfig::${DEP_NAME})
endforeach()
