cmake_minimum_required(VERSION 3.25)
project(wetware VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_compile_options(
  -Wall
  -Wextra
  -Wpedantic
  -Wconversion
  -Wsign-conversion
  -Wshadow
)

add_library(wetware_sim STATIC
  src/simulation.cpp
)
target_include_directories(wetware_sim PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/include
)

add_executable(wetware_cli
  src/wetware_cli.cpp
)
target_link_libraries(wetware_cli PRIVATE wetware_sim)

enable_testing()

add_executable(wetware_simulation_test
  test/simulation_test.cpp
)
target_link_libraries(wetware_simulation_test PRIVATE wetware_sim)

add_test(NAME wetware_simulation_test COMMAND wetware_simulation_test)
