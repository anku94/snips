cmake_minimum_required(VERSION 2.8)
project(blktest)

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")

find_package (BLKID REQUIRED)

add_executable(run_blkid run_blkid.cc)

if (BLKID_FOUND)
  add_definitions(-DPRELOAD_HAS_BLKID)
  target_link_libraries(run_blkid blkid)
endif()
